typedef unsigned long long uint64_t;
typedef unsigned char      uint8_t;

extern volatile uint64_t tohost;

void htif_console_putchar(char c) {
    uint64_t payload = 0x0101000000000000 | (uint8_t)c;
    while (tohost != 0);
    tohost = payload;
}

void print_str(const char *s) { 
    while (*s) htif_console_putchar(*s++); 
}

void print_int(int n) {
    if (n == 0) { htif_console_putchar('0'); return; }
    char buf[32]; 
    int i = 0;
    while (n > 0) { buf[i++] = (n % 10) + '0'; n /= 10; }
    while (--i >= 0) htif_console_putchar(buf[i]);
}

int main() {
    print_str("Calculation Result: ");
    print_int(10 + 20);
    print_str("\n");
    return 0;
}
