volatile unsigned int *ram_test =
    (volatile unsigned int *)0x00000100;

int main(void)
{
    *ram_test = 42;

    volatile unsigned int value = *ram_test;

    while (value != 42)
        ;

    return 0;
}