

void func1( void ) {}
void func2( void ) {}
void func3( void ) {}


struct file_operations {
   char *owner1;
   const char * const owner2;
   void (*field1)(void);
   void (*field2)(void);
   void (*field3)(void);
};

const char str[] = "TESTTESTTEST";


struct file_operations ops = {
   .owner1 = "TEST",
   .owner2 = str,
   .field1 = func1,
   .field2 = func2,
};


int main()
{
   return 0;
}

