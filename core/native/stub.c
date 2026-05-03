#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

static char *papion_local_result_buf = NULL;
static char *papion_local_error_buf = NULL;

static void papion_local_replace(char **slot, const char *value) {
  if (*slot != NULL) {
    free(*slot);
  }
  *slot = strdup(value == NULL ? "" : value);
}

static void papion_local_set_errorf(const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  char stack_buf[1024];
  vsnprintf(stack_buf, sizeof(stack_buf), fmt, args);
  va_end(args);
  papion_local_replace(&papion_local_error_buf, stack_buf);
}

static void papion_local_set_result(const char *value) {
  papion_local_replace(&papion_local_result_buf, value);
}

int papion_local_result_len(void) {
  return papion_local_result_buf == NULL ? 0 : (int)strlen(papion_local_result_buf);
}

int papion_local_error_len(void) {
  return papion_local_error_buf == NULL ? 0 : (int)strlen(papion_local_error_buf);
}

int papion_local_result_byte(int index) {
  if (papion_local_result_buf == NULL || index < 0) {
    return 0;
  }
  size_t len = strlen(papion_local_result_buf);
  if ((size_t)index >= len) {
    return 0;
  }
  return (unsigned char)papion_local_result_buf[index];
}

int papion_local_error_byte(int index) {
  if (papion_local_error_buf == NULL || index < 0) {
    return 0;
  }
  size_t len = strlen(papion_local_error_buf);
  if ((size_t)index >= len) {
    return 0;
  }
  return (unsigned char)papion_local_error_buf[index];
}

int papion_local_realpath(const char *path) {
  char resolved[PATH_MAX];
  if (realpath(path, resolved) == NULL) {
    papion_local_set_errorf("failed to resolve %s: %s", path, strerror(errno));
    return 0;
  }
  papion_local_set_result(resolved);
  return 1;
}

int papion_local_path_kind(const char *path) {
  struct stat st;
  if (stat(path, &st) != 0) {
    if (errno == ENOENT) {
      return 0;
    }
    papion_local_set_errorf("failed to stat %s: %s", path, strerror(errno));
    return -1;
  }
  if (S_ISDIR(st.st_mode)) {
    return 2;
  }
  if (S_ISREG(st.st_mode)) {
    return 1;
  }
  return 0;
}

int papion_local_list_dir(const char *path) {
  DIR *dir = opendir(path);
  if (dir == NULL) {
    papion_local_set_errorf("failed to open directory %s: %s", path, strerror(errno));
    return 0;
  }
  size_t capacity = 256;
  size_t length = 0;
  char *buffer = malloc(capacity);
  if (buffer == NULL) {
    closedir(dir);
    papion_local_set_errorf("failed to allocate directory buffer");
    return 0;
  }
  buffer[0] = '\0';
  struct dirent *entry;
  while ((entry = readdir(dir)) != NULL) {
    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
      continue;
    }
    size_t name_len = strlen(entry->d_name);
    size_t needed = length + name_len + (length == 0 ? 1 : 2);
    if (needed > capacity) {
      while (needed > capacity) {
        capacity *= 2;
      }
      char *grown = realloc(buffer, capacity);
      if (grown == NULL) {
        free(buffer);
        closedir(dir);
        papion_local_set_errorf("failed to grow directory buffer");
        return 0;
      }
      buffer = grown;
    }
    if (length != 0) {
      buffer[length++] = '\n';
    }
    memcpy(buffer + length, entry->d_name, name_len);
    length += name_len;
    buffer[length] = '\0';
  }
  closedir(dir);
  papion_local_set_result(buffer);
  free(buffer);
  return 1;
}

int papion_local_make_temp_dir(const char *prefix) {
  char templ[PATH_MAX];
  snprintf(templ, sizeof(templ), "%sXXXXXX", prefix);
  char *made = mkdtemp(templ);
  if (made == NULL) {
    papion_local_set_errorf("failed to create temp dir for %s: %s", prefix, strerror(errno));
    return 0;
  }
  papion_local_set_result(made);
  return 1;
}

int papion_local_mkdir_p(const char *path) {
  char buffer[PATH_MAX];
  size_t len = strlen(path);
  if (len >= sizeof(buffer)) {
    papion_local_set_errorf("path too long: %s", path);
    return 0;
  }
  memcpy(buffer, path, len + 1);
  for (size_t i = 1; i < len; ++i) {
    if (buffer[i] == '/') {
      buffer[i] = '\0';
      if (mkdir(buffer, 0777) != 0 && errno != EEXIST) {
        papion_local_set_errorf("failed to mkdir %s: %s", buffer, strerror(errno));
        return 0;
      }
      buffer[i] = '/';
    }
  }
  if (mkdir(buffer, 0777) != 0 && errno != EEXIST) {
    papion_local_set_errorf("failed to mkdir %s: %s", buffer, strerror(errno));
    return 0;
  }
  return 1;
}

int papion_local_write_file(const char *path, const char *content) {
  FILE *file = fopen(path, "wb");
  if (file == NULL) {
    papion_local_set_errorf("failed to open %s for writing: %s", path, strerror(errno));
    return 0;
  }
  size_t len = strlen(content);
  if (len > 0 && fwrite(content, 1, len, file) != len) {
    fclose(file);
    papion_local_set_errorf("failed to write %s: %s", path, strerror(errno));
    return 0;
  }
  fclose(file);
  return 1;
}
