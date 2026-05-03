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
static size_t papion_local_result_buf_len = 0;
static char *papion_local_error_buf = NULL;

static const char papion_oom_msg[] = "out of memory";

static void papion_local_replace_err(const char *value) {
  if (papion_local_error_buf != NULL &&
      papion_local_error_buf != (char *)papion_oom_msg) {
    free(papion_local_error_buf);
  }
  papion_local_error_buf = strdup(value == NULL ? "" : value);
  if (papion_local_error_buf == NULL) {
    // strdup failed; point at the static OOM string so callers always see
    // a non-NULL error buffer rather than a silent empty error.
    papion_local_error_buf = (char *)papion_oom_msg;
  }
}

// Returns 1 on success, 0 on allocation failure. On failure the error buffer
// is set to a static OOM message and the result buffer is cleared.
static int papion_local_replace_result(const char *value, size_t len) {
  if (papion_local_result_buf != NULL &&
      papion_local_result_buf != (char *)papion_oom_msg) {
    free(papion_local_result_buf);
  }
  papion_local_result_buf = NULL;
  papion_local_result_buf_len = 0;
  if (len == 0) {
    return 1;
  }
  papion_local_result_buf = malloc(len);
  if (papion_local_result_buf == NULL) {
    papion_local_replace_err(papion_oom_msg);
    return 0;
  }
  memcpy(papion_local_result_buf, value, len);
  papion_local_result_buf_len = len;
  return 1;
}

static void papion_local_set_errorf(const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  char stack_buf[1024];
  vsnprintf(stack_buf, sizeof(stack_buf), fmt, args);
  va_end(args);
  papion_local_replace_err(stack_buf);
}

static int papion_local_set_result(const char *value) {
  size_t len = value == NULL ? 0 : strlen(value);
  return papion_local_replace_result(value, len);
}

int papion_local_result_len(void) {
  return (int)papion_local_result_buf_len;
}

int papion_local_error_len(void) {
  return papion_local_error_buf == NULL ? 0 : (int)strlen(papion_local_error_buf);
}

int papion_local_result_byte(int index) {
  if (papion_local_result_buf == NULL || index < 0) {
    return 0;
  }
  if ((size_t)index >= papion_local_result_buf_len) {
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
  if (!papion_local_set_result(resolved)) {
    return 0;
  }
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

int papion_local_is_symlink(const char *path) {
  struct stat st;
  if (lstat(path, &st) != 0) {
    return 0;
  }
  return S_ISLNK(st.st_mode) ? 1 : 0;
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
  struct dirent *entry;
  while ((entry = readdir(dir)) != NULL) {
    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
      continue;
    }
    // Each entry is stored as name\0; entries are NUL-delimited with no
    // separator before the first entry and no extra NUL at the end.
    size_t name_len = strlen(entry->d_name);
    size_t needed = length + name_len + 1;
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
    memcpy(buffer + length, entry->d_name, name_len);
    length += name_len;
    buffer[length++] = '\0';
  }
  closedir(dir);
  int ok = papion_local_replace_result(buffer, length);
  free(buffer);
  return ok;
}

int papion_local_make_temp_dir(const char *prefix) {
  char templ[PATH_MAX];
  snprintf(templ, sizeof(templ), "%sXXXXXX", prefix);
  char *made = mkdtemp(templ);
  if (made == NULL) {
    papion_local_set_errorf("failed to create temp dir for %s: %s", prefix, strerror(errno));
    return 0;
  }
  if (!papion_local_set_result(made)) {
    return 0;
  }
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
