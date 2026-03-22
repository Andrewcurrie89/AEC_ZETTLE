-- Zettelkasten schema
-- Run this in Supabase: SQL Editor → New query → paste and run

create table if not exists zettels (
    id          uuid primary key default gen_random_uuid(),
    title       text not null,
    body        text,
    type        text not null default 'note',  -- note | idea | contact | organization | reference
    tags        text[] default '{}',
    metadata    jsonb default '{}',
    created_at  timestamptz default now(),
    updated_at  timestamptz default now(),
    -- generated column for full-text search
    fts         tsvector generated always as (
                    to_tsvector('english', title || ' ' || coalesce(body, ''))
                ) stored
);

create table if not exists zettel_links (
    id           uuid primary key default gen_random_uuid(),
    source_id    uuid references zettels(id) on delete cascade,
    target_id    uuid references zettels(id) on delete cascade,
    relationship text default 'related',  -- related | inspired_by | part_of | contradicts | see_also
    created_at   timestamptz default now(),
    unique(source_id, target_id)
);

-- Indexes
create index if not exists zettels_fts_idx     on zettels using gin(fts);
create index if not exists zettels_tags_idx    on zettels using gin(tags);
create index if not exists zettels_type_idx    on zettels(type);
create index if not exists zettels_created_idx on zettels(created_at desc);

-- Auto-update updated_at on row changes
create or replace function update_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create or replace trigger zettels_updated_at
    before update on zettels
    for each row
    execute function update_updated_at();

-- Enable row-level security (Supabase default — service_role bypasses it)
alter table zettels      enable row level security;
alter table zettel_links enable row level security;
