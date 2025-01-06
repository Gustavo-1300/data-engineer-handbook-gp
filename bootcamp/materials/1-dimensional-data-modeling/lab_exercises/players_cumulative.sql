SELECT * FROM player_seasons;

CREATE TYPE season_stats AS (
	season INTEGER,
	gp REAL,
	pts REAL,
	reb REAL,
	ast REAL,
	netrtg REAL,
	weigth INTEGER
);

CREATE TYPE scoring_class AS ENUM ('star', 'good', 'average', 'bad');

CREATE TABLE players (
	player_name TEXT,
	year_born INTEGER,
	height TEXT,
	college TEXT,
	country TEXT,
	draft_year TEXT,
	draft_round TEXT,
	draft_number TEXT,
	season_stats season_stats[],
	scoring_class scoring_class,
	years_since_active INTEGER,
	is_active BOOLEAN,
	current_season INTEGER,
	PRIMARY KEY (player_name, current_season)
);

WITH season_add AS (
	SELECT 2001 AS season_add
),
	last_season AS (
	SELECT *
	FROM players
	WHERE current_season = (SELECT season_add - 1 FROM season_add)
),
	current_season AS (
	SELECT *
	FROM player_seasons
	WHERE season = (SELECT season_add FROM season_add)
)
INSERT INTO players
SELECT
	COALESCE(ls.player_name, cs.player_name) AS player_name,
	COALESCE(ls.year_born, cs.season - cs.age) AS year_born,
	COALESCE(ls.height, cs.height) AS height,
	COALESCE(ls.college, cs.college) AS college,
	COALESCE(ls.country, cs.country) AS country,
	COALESCE(ls.draft_year, cs.draft_year) AS draft_year,
	COALESCE(ls.draft_round, cs.draft_round) AS draft_round,
	COALESCE(ls.draft_number, cs.draft_number) AS draft_number,
	COALESCE(
		ls.season_stats,
		ARRAY[]::season_stats[]
	) || CASE WHEN cs.season IS NOT NULL THEN
			ARRAY[ROW(cs.season, cs.gp, cs.pts, cs.reb, cs.ast,
					cs.netrtg, cs.weight)::season_stats]
			ELSE ARRAY[]::season_stats[] END
	AS season_stats,
	CASE WHEN cs.season IS NOT NULL THEN 
		(CASE WHEN cs.netrtg > 15 THEN 'star'
		WHEN cs.netrtg > 7.5 THEN 'good'
		WHEN cs.netrtg > 1 THEN 'average'
		ELSE 'bad' END)::scoring_class
		ELSE ls.scoring_class END
	AS scoring_class,
	CASE WHEN cs.season IS NOT NULL THEN 0
		ELSE COALESCE(ls.years_since_active, 0) + 1 END
	AS years_since_active,
	cs.season IS NOT NULL AS is_active,
	COALESCE(ls.current_season + 1, cs.season) AS current_season
	FROM last_season ls
	FULL OUTER JOIN current_season cs
	ON ls.player_name = cs.player_name;

SELECT * FROM players
WHERE current_season = 2001;