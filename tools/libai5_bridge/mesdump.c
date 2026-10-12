/* mesdump - read one raw MES entry (a file, or stdin) and list every statement
 * libai5 recognises under a chosen game grammar.
 *
 *   mesdump <game> parse [file]   one line per statement:
 *                                   STMT <address> <next_address> <op> <text>
 *                                 then "OK <code_size> <count>" or "FAIL <offset>"
 *   mesdump <game> print [file]   libai5's flat listing of the whole entry
 *
 * The entry's address-table header (u32 count + count u32 entries) is skipped
 * the way kakyu-mod-tools' container does, so every address is code-relative
 * and comparable with the repo's typed IR. Built by build_mesdump.py against a
 * libai5 checkout (GPL-2.0, https://github.com/nunuhara/libai5); this file is
 * the only source the bridge adds. For Kakyu complete's archive the grammar to
 * use is "nonomura" (the 2003 AI5WIN generation with an address table,
 * DEF_SUB/CALL_SUB and the 0x0B..0x1F statement numbering).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#ifdef _WIN32
#include <io.h>
#include <fcntl.h>
#endif

#include "nulib.h"
#include "nulib/port.h"
#include "ai5/game.h"
#include "ai5/mes.h"

static uint8_t *read_all(FILE *fp, size_t *size_out)
{
	size_t cap = 1 << 20, size = 0;
	uint8_t *buf = malloc(cap);
	size_t n;
	while ((n = fread(buf + size, 1, cap - size, fp)) > 0) {
		size += n;
		if (size == cap) {
			cap *= 2;
			buf = realloc(buf, cap);
		}
	}
	*size_out = size;
	return buf;
}

static uint32_t le32(const uint8_t *p)
{
	return p[0] | (p[1] << 8) | (p[2] << 16) | ((uint32_t)p[3] << 24);
}

int main(int argc, char **argv)
{
	if (argc < 3) {
		fprintf(stderr, "usage: mesdump <game> parse|print [file]\n");
		return 2;
	}
	ai5_set_game(argv[1]);
	mes_set_game(ai5_target_game);
	FILE *fp = stdin;
	if (argc > 3) {
		fp = fopen(argv[3], "rb");
		if (!fp) {
			perror(argv[3]);
			return 2;
		}
	}
#ifdef _WIN32
	if (fp == stdin)
		_setmode(_fileno(stdin), _O_BINARY);
	_setmode(_fileno(stdout), _O_BINARY);
#endif
	size_t size;
	uint8_t *payload = read_all(fp, &size);
	if (size < 4) {
		fprintf(stderr, "entry too small\n");
		return 1;
	}
	uint32_t count = le32(payload);
	size_t code_offset = 4 + (size_t)count * 4;
	if (code_offset > size) {
		fprintf(stderr, "address table exceeds entry\n");
		return 1;
	}
	uint8_t *code = payload + code_offset;
	size_t code_size = size - code_offset;
	struct port *out = port_stdout();

	if (!strcmp(argv[2], "print")) {
		mes_statement_list list = vector_initializer;
		bool ok = mes_parse_statements(code, code_size, &list);
		mes_flat_statement_list_print(list, out);
		printf("%s %u statements\n", ok ? "OK" : "FAIL", (unsigned)vector_length(list));
		return ok ? 0 : 1;
	}

	size_t off = 0;
	unsigned n = 0;
	while (off < code_size) {
		struct mes_statement *stmt = mes_parse_statement(code + off, code_size - off);
		if (!stmt) {
			printf("FAIL %zu\n", off);
			fflush(stdout);
			return 1;
		}
		printf("STMT %zu %zu %u ", off, off + stmt->next_address, (unsigned)stmt->op);
		fflush(stdout);
		mes_statement_print(stmt, out);
		port_flush(out);
		if (stmt->next_address == 0) {
			printf("FAIL %zu (no progress)\n", off);
			return 1;
		}
		off += stmt->next_address;
		mes_statement_free(stmt);
		n++;
	}
	printf("OK %zu %u\n", code_size, n);
	return 0;
}
