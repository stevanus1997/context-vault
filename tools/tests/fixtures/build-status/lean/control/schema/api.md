# api — Schema (proyeksi; JANGAN edit tangan — di-generate dari skema/migrasi app)

## users
Kolom  : id uuid [pk] · email text [unique]

## orders
Kolom  : id uuid [pk] · user_id uuid [fk→users]
