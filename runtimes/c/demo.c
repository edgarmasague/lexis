#include <stdio.h>
#include "lexis.h"

int main(void) {
    Lexis *lex = lexis_new("lang", NULL, NULL);  /* Auto-detecta locale */
    
    char buf[1024];
    lexis_get(lex, "welcome", buf, sizeof(buf), "Lexis");
    printf("%s\n", buf);  /* "Bienvenido a Lexis" si $LANG=es */
    
    lexis_get(lex, "progress", buf, sizeof(buf), 42);
    printf("%s\n", buf);  /* "Progreso: 42% completado" */
    
    lexis_reload(lex, "en", NULL);  /* Cambia a inglés */
    lexis_get(lex, "welcome", buf, sizeof(buf), "Lexis");
    printf("%s\n", buf);  /* "Welcome to Lexis" */
    
    lexis_free(lex);
    return 0;
}