-- Registros de KM Rodado — schema Supabase (rodar no SQL Editor do projeto GBS: ndwivbhqglpnfyqwjbzu)
-- Mesmo script serve pro MNS (projeto aqflznkwvhnvhxqvjoax), sem nenhuma alteração.

create table if not exists veiculos (
  placa text primary key,
  condutor text,
  tipo text,
  base text,
  marca text,
  atualizado_em timestamptz not null default now()
);

create table if not exists registros_km (
  id bigint generated always as identity primary key,
  placa text not null,
  base text,
  data date not null,
  hora_inicio time not null,
  km_inicial numeric(10,2) not null,
  km_final numeric(10,2) not null,
  km_rodado numeric(10,2) not null,
  mes_ref text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_registros_km_mes_ref on registros_km (mes_ref);
create index if not exists idx_registros_km_placa on registros_km (placa);
create index if not exists idx_registros_km_base on registros_km (base);

-- Guarda o motivo de cada registro/veículo excluído no upload (odômetro inconsistente),
-- pra poder mostrar o aviso no Painel sempre que aquele mês for visto, não só na hora do upload.
create table if not exists registros_km_exclusoes (
  id bigint generated always as identity primary key,
  mes_ref text not null,
  placa text not null,
  base text,
  tipo text not null, -- 'veiculo_invalidado' (o veiculo inteiro saiu do mes) | 'registro_individual'
  motivo text not null,
  data date,          -- null quando tipo = 'veiculo_invalidado'
  hora_inicio time,
  km_inicial numeric(10,2),
  km_final numeric(10,2),
  created_at timestamptz not null default now()
);
create index if not exists idx_registros_km_exclusoes_mes_ref on registros_km_exclusoes (mes_ref);

-- Lista de meses com dados, sem precisar baixar a tabela inteira só pra isso
-- (mesmo padrão de meses_impedimentos/meses_leituras_acertadas já usado no GBS).
create or replace function meses_registros_km()
returns table(mes_ref text) language sql stable as $$
  select distinct mes_ref from registros_km order by mes_ref desc;
$$;

-- Sem RLS habilitado de propósito: nenhuma outra tabela do sistema usa RLS hoje
-- (controle de acesso é feito no JS do módulo, com a chave anon), então habilitar
-- aqui sem policies quebraria o acesso normal do front-end. Ver pendência já
-- registrada sobre revisar RLS no Supabase do GBS/MNS de forma geral.

-- ============================================================
-- MIGRAÇÃO: filtro de Proprietário (Moto Própria / Moto Locada) e
-- faixas de horário configuráveis (Dentro Horário / Fora Horário)
-- Rodar uma vez no SQL Editor do Supabase (projeto ndwivbhqglpnfyqwjbzu).
-- ============================================================
alter table veiculos add column if not exists proprietario text;

create table if not exists km_horario_config (
  id int primary key default 1,
  dentro_de time not null default '07:00',
  dentro_ate time not null default '17:00',
  fora_de time not null default '17:00',
  fora_ate time not null default '07:00',
  atualizado_em timestamptz not null default now(),
  constraint km_horario_config_id_check check (id = 1)
);
insert into km_horario_config (id) values (1) on conflict (id) do nothing;
