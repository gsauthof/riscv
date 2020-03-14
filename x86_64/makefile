
CFLAGS = -Wall

bcd2a: ../main_bcd2a.c bcd2ascii.S
	$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) -o $@ $^

TEMP += bcd2a

bcd2a-sse: ../main_bcd2a.c bcd2ascii-sse.S
	$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) -o $@ $^

TEMP += bcd2a-sse

.PHONY: clean
clean:
	rm -f $(TEMP)
