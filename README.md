# Painel de Campanhas 2027 · 60 Minutos Escape Game

Painel com o cronograma sazonal de 2027. A equipe marca cada etapa como feita, e a marcação aparece na hora para todos.

- **Página:** `index.html`, hospedada no GitHub Pages
- **Marcações:** guardadas no Supabase (plano gratuito)
- **Quem marca:** qualquer pessoa com o link, usando o próprio nome e a senha do time
- **Quem só vê:** qualquer pessoa com o link vê o painel, sem login

## 1. Supabase (uma vez)

1. Em supabase.com, crie um projeto.
2. Abra **SQL Editor > New query** e cole o conteúdo de `supabase-setup.sql`.
3. No script, troque `TROQUE_ESTA_SENHA` pela senha do time.
4. Clique em **Run**.
5. Em **Project Settings > API**, copie:
   - **Project URL**
   - **anon public key**

## 2. Ligar a página ao Supabase

Abra `index.html` e procure `PAINEL_CONFIG`. Cole os dois valores do passo anterior:

```js
SUPABASE_URL: "https://xxxx.supabase.co",
SUPABASE_ANON_KEY: "eyJ..."
```

A anon key é pública por natureza e pode ficar na página. A senha do time não aparece na página: ela fica guardada no banco.

## 3. GitHub Pages

1. Crie um repositório, por exemplo `painel-60minutos`, e envie `index.html`.
2. Vá em **Settings > Pages > Branch: main / root > Save**.
3. Em cerca de 1 minuto, o link fica disponível: `https://SEU-USUARIO.github.io/painel-60minutos/`

Atenção: no plano gratuito do GitHub, o Pages só funciona com repositório **público**. A página e o cronograma ficam visíveis para quem tiver o link, mas as marcações só podem ser alteradas por quem tem a senha.

## Trocar a senha do time

No **SQL Editor** do Supabase, rode o comando abaixo:

```sql
update public.painel_config set valor = 'NOVA_SENHA' where chave = 'senha_time';
```

Quem estava logado com a senha antiga precisa entrar de novo.
