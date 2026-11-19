-- =====================================================================
-- Painel de Campanhas 2027 · 60 Minutos Escape Game
-- Cole este script inteiro no Supabase: SQL Editor > New query > Run
-- ANTES DE RODAR: troque  TROQUE_ESTA_SENHA  pela senha do time.
-- =====================================================================

-- 1) Marcações (qualquer pessoa com o link pode LER)
create table if not exists public.marcacoes (
  id        text primary key,          -- "campanha__etapa"
  feito     boolean not null default true,
  por       text,                      -- nome de quem marcou
  em        timestamptz not null default now(),
  campanha  text,
  etapa     text
);

alter table public.marcacoes enable row level security;

drop policy if exists "leitura publica" on public.marcacoes;
create policy "leitura publica" on public.marcacoes
  for select to anon, authenticated using (true);
grant usage on schema public to anon, authenticated;
grant select on public.marcacoes to anon, authenticated;
revoke insert, update, delete on public.marcacoes from anon, authenticated;
-- Sem políticas de insert/update/delete: só dá para gravar pelas funções abaixo.

-- 2) Senha do time (tabela privada, invisível pela página)
create table if not exists public.painel_config (
  chave text primary key,
  valor text not null
);
alter table public.painel_config enable row level security;
-- (nenhuma política = ninguém lê pela API pública)

insert into public.painel_config (chave, valor)
values ('senha_time', 'TROQUE_ESTA_SENHA')
on conflict (chave) do update set valor = excluded.valor;

-- 3) Conferir a senha
create or replace function public.verificar_senha(p_senha text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (select 1 from painel_config where chave = 'senha_time' and valor = p_senha);
$$;

-- 4) Marcar / desmarcar uma etapa (exige a senha)
create or replace function public.marcar_etapa(
  p_senha text, p_id text, p_feito boolean,
  p_por text, p_campanha text, p_etapa text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from painel_config where chave = 'senha_time' and valor = p_senha) then
    return false;
  end if;
  if length(p_id) > 200 or length(coalesce(p_por, '')) > 60 then
    return false;
  end if;
  if p_feito then
    insert into marcacoes (id, feito, por, em, campanha, etapa)
    values (p_id, true, left(p_por, 60), now(), left(p_campanha, 120), left(p_etapa, 120))
    on conflict (id) do update
      set feito = true, por = excluded.por, em = now(),
          campanha = excluded.campanha, etapa = excluded.etapa;
  else
    delete from marcacoes where id = p_id;
  end if;
  return true;
end;
$$;

revoke all on function public.verificar_senha(text) from public;
revoke all on function public.marcar_etapa(text, text, boolean, text, text, text) from public;
grant execute on function public.verificar_senha(text) to anon, authenticated;
grant execute on function public.marcar_etapa(text, text, boolean, text, text, text) to anon, authenticated;

-- 5) Atualização em tempo real para todo o time
alter table public.marcacoes replica identity full;
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'marcacoes'
  ) then
    alter publication supabase_realtime add table public.marcacoes;
  end if;
end $$;

-- 6) Trazer as marcações que já existem no painel do Claude
insert into public.marcacoes (id, feito, por, em, campanha, etapa) values
  ('ferias-de-janeiro-2027__plan', true, 'Marketing', '2026-11-19T19:48:11Z', 'Férias de janeiro 2027', 'Planejamento e criação'),
  ('ferias-de-janeiro-2027__pre',  true, 'Marketing', '2026-11-19T19:48:12Z', 'Férias de janeiro 2027', 'Pré-venda aberta')
on conflict (id) do nothing;

-- Para trocar a senha depois:
--   update public.painel_config set valor = 'NOVA_SENHA' where chave = 'senha_time';
