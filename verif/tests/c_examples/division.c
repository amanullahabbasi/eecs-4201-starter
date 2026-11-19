/* The volatile inputs keep the divide and remainder instructions in the image. */
volatile int numerator = 73;
volatile int denominator = 5;

int main(void)
{
    int quotient = numerator / denominator;
    int remainder = numerator % denominator;
    return (quotient == 14 && remainder == 3) ? 1 : 0;
}
