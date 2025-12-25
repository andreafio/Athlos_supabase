# Processo di Review e Merge

- Ogni modifica a schema, policy o microservizi deve avvenire tramite Pull Request (PR)
- È richiesta la review di almeno un altro sviluppatore
- I test (inclusi test RLS) devono passare prima del merge
- Aggiornare sempre CHANGELOG.md e la documentazione correlata
- Nessuna modifica diretta su main/master
- Usare i naming convention formali per tutte le nuove entità
- In caso di breaking change, incrementare la versione API e documentare la deprecazione
