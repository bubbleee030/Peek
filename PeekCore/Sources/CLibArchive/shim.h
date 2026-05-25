#ifndef PEEK_CLIBARCHIVE_SHIM_H
#define PEEK_CLIBARCHIVE_SHIM_H

#include <stddef.h>

/* macOS links libarchive (libarchive.tbd is in the SDK) but ships no public
   headers, so we declare exactly the symbols we use. Verified exported. */

struct archive;
struct archive_entry;

struct archive *archive_read_new(void);
int archive_read_support_filter_all(struct archive *);
int archive_read_support_format_all(struct archive *);
int archive_read_open_filename(struct archive *, const char *filename, size_t block_size);
int archive_read_next_header(struct archive *, struct archive_entry **);
int archive_read_data_skip(struct archive *);
int archive_read_free(struct archive *);
const char *archive_error_string(struct archive *);

const char *archive_entry_pathname(struct archive_entry *);
long long archive_entry_size(struct archive_entry *);
long archive_entry_mtime(struct archive_entry *);
unsigned short archive_entry_filetype(struct archive_entry *);

#endif
