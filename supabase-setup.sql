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

-- =====================================================================
-- 7) Mapa de oportunidades (aba "Oportunidades")
--    Preenchido pela pesquisa semanal; a equipe muda status e nota com a senha do time.
-- =====================================================================
create table if not exists public.oportunidades (
  id text primary key, titulo text not null, categoria text not null, universo text, salas text, unidades text,
  data_inicio date, data_fim date, data_texto text,
  confirmacao text not null default 'prevista' check (confirmacao in ('confirmada','prevista','rumor','a confirmar')),
  usos text[] not null default '{}', ideia text, parceiro text, fonte_titulo text, fonte_url text,
  status text not null default 'nova' check (status in ('nova','em_analise','aprovada','descartada')),
  nota text, encontrada_em date not null default current_date, atualizado_em timestamptz not null default now(), atualizado_por text
);
alter table public.oportunidades enable row level security;
drop policy if exists "leitura publica" on public.oportunidades;
create policy "leitura publica" on public.oportunidades for select to anon, authenticated using (true);
grant select on public.oportunidades to anon, authenticated;
revoke insert, update, delete on public.oportunidades from anon, authenticated;

create or replace function public.atualizar_oportunidade(p_senha text, p_id text, p_status text, p_nota text, p_por text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.painel_config where chave = 'senha_time' and valor = p_senha) then return false; end if;
  if p_status not in ('nova','em_analise','aprovada','descartada') then return false; end if;
  update public.oportunidades set status = p_status, nota = left(p_nota, 500), atualizado_em = now(), atualizado_por = left(p_por, 60) where id = p_id;
  return found;
end; $$;
revoke all on function public.atualizar_oportunidade(text, text, text, text, text) from public;
grant execute on function public.atualizar_oportunidade(text, text, text, text, text) to anon, authenticated;
alter table public.oportunidades replica identity full;

create table if not exists public.pesquisas (
  id bigint generated always as identity primary key, rodada_em timestamptz not null default now(),
  novas int not null default 0, atualizadas int not null default 0, resumo text
);
alter table public.pesquisas enable row level security;
drop policy if exists "leitura publica" on public.pesquisas;
create policy "leitura publica" on public.pesquisas for select to anon, authenticated using (true);
grant select on public.pesquisas to anon, authenticated;
