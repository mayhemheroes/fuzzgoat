/* In-process libFuzzer harness for fuzzgoat.
 *
 * Drives the SAME code path as upstream main.c: allocate an exact-size buffer,
 * copy the input into it, json_parse() it, then json_value_free() the result.
 * fuzzgoat's deliberate memory-corruption bugs live in json_value_free(), so the
 * harness MUST free the parsed value (as main.c does) to reach them. The buffer
 * is heap-allocated at exactly `size` bytes (like main.c's malloc(file_size)) so a
 * genuine over-read in the parser is caught by ASan rather than masked. Converting
 * the original `/fuzzgoat @@` file-input CLI to this coverage-guided harness keeps
 * the code path (json_parse + json_value_free) while giving Mayhem edge coverage.
 */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "fuzzgoat.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    char *buf = (char *) malloc(size);
    if (buf == NULL) {
        return 0;
    }
    if (size != 0) {
        memcpy(buf, data, size);
    }

    json_value *value = json_parse((json_char *) buf, size);
    if (value != NULL) {
        json_value_free(value);
    }

    free(buf);
    return 0;
}
