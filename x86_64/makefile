
CFLAGS = -Wall

bcd2a: ../main_bcd2a.c bcd2ascii.S
	$(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) -o $@ $^

TEMP += bcd2a

.PHONY: clean
clean:
	rm -f $(TEMP)
