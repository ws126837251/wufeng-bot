Application.load(:policr_mini)
{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = PolicrMini.Repo.start_link()

migrations_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])
Ecto.Migrator.run(PolicrMini.Repo, migrations_path, :up, all: true)
