#include <syslog.h>
#include <stdio.h>

int main(int argc, char *argv[])
{

    openlog("writer_wanagata", LOG_PID | LOG_NDELAY, LOG_USER);
    // Check for exactly 3 arguments (program name + writefile + writestr)
    if (argc != 3)
    {
        syslog(LOG_ERR, "Error : Mising arguments");
        syslog(LOG_INFO, "Usage: writer.exe <writefile> <writestr>");
    }

    FILE *file;
    
    file = fopen(argv[1], "w");
    if (!file)
    {
        syslog(LOG_ERR, "Error: Cannot create file %s", argv[1]);
        return 1;
    }

    fprintf(file, "%s", argv[2]);
    fclose(file);

    // read and print
    file = fopen(argv[1], "r");
    if (!file)
    {
        syslog(LOG_ERR, "Error: Cannot open file %s for reading", argv[1]);
        return 1;
    }
    int c = 0 ;
    
    while ((c = fgetc(file)) != EOF)
    {
        printf("%c", c);
    }
    fclose(file);

    syslog(LOG_INFO, "Writing %s to %s", argv[2], argv[1]);
    closelog();

    return 0;
}