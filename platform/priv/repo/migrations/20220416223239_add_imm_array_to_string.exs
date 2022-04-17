defmodule Platform.Repo.Migrations.AddImmArrayToString do
  use Ecto.Migration

  def change do
    execute """
              CREATE OR REPLACE FUNCTION imm_array_to_string(character varying[], text, text)
              RETURNS text LANGUAGE sql IMMUTABLE AS $$select array_to_string(coalesce($1, '{}'), $2, $3)$$
            """,
            ""
  end
end
