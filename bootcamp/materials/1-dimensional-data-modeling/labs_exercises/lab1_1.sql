CREATE TYPE season_stats AS (
	season INTEGER,
	gp INTEGER,
	pts REAL,
	reb REAL,
	ast REAL
);

CREATE TYPE scoring_class AS ENUM ('star', 'good', 'average', 'bad');

DROP TABLE players;

CREATE TABLE players (
	player_name TEXT,
	height TEXT,
	college TEXT,
	country TEXT,
	draft_year TEXT,
	draft_round TEXT,
	draft_number TEXT,
	season_stats season_stats[],
	scoring_class scoring_class,
	years_since_last_season INTEGER,
	is_active boolean,
	current_season INTEGER,
	PRIMARY KEY(player_name, current_season)
);

INSERT INTO players
WITH years AS (
	SELECT *
	FROM generate_series(1996, 2022) AS season
),
-- Deduplicate player_seasons: one row per (player_name, season)
player_seasons_deduped AS (
	SELECT
		player_name, season,
		SUM(gp) AS gp,
		AVG(pts) AS pts,
		AVG(reb) AS reb,
		AVG(ast) AS ast
	FROM player_seasons
	GROUP BY player_name, season
),
-- Static player attributes (most recent non-null values)
player_attrs AS (
	SELECT DISTINCT ON (player_name)
		player_name, height, college, country,
		draft_year, draft_round, draft_number
	FROM player_seasons
	ORDER BY player_name, season DESC
),
-- First season each player appeared in
player_first_season AS (
	SELECT player_name, MIN(season) AS first_season
	FROM player_seasons_deduped
	GROUP BY player_name
),
-- Generate a row for every (player, year) from their first season through 2022
player_years AS (
	SELECT pfs.player_name, y.season AS current_season
	FROM player_first_season pfs
	CROSS JOIN years y
	WHERE y.season >= pfs.first_season
),
-- For each (player, current_season), aggregate all active seasons up to that point
player_cumulative AS (
	SELECT
		py.player_name,
		py.current_season,
		pa.height,
		pa.college,
		pa.country,
		pa.draft_year,
		pa.draft_round,
		pa.draft_number,
		-- Cumulative season_stats array
		ARRAY_AGG(
			ROW(ps.season, ps.gp, ps.pts, ps.reb, ps.ast)::season_stats
			ORDER BY ps.season
		) FILTER (WHERE ps.season IS NOT NULL) AS season_stats,
		-- Most recent active season's pts (for scoring_class)
		(ARRAY_AGG(ps.pts ORDER BY ps.season DESC)
			FILTER (WHERE ps.season IS NOT NULL)
		)[1] AS last_pts,
		-- Years since last active season
		py.current_season - MAX(ps.season) AS years_since_last_season,
		MAX(ps.season) = py.current_season AS is_active
	FROM player_years py
	JOIN player_attrs pa ON py.player_name = pa.player_name
	LEFT JOIN player_seasons_deduped ps
		ON py.player_name = ps.player_name
		AND ps.season <= py.current_season
	GROUP BY py.player_name, py.current_season,
		pa.height, pa.college, pa.country,
		pa.draft_year, pa.draft_round, pa.draft_number
)
SELECT
	player_name,
	height,
	college,
	country,
	draft_year,
	draft_round,
	draft_number,
	season_stats,
	CASE
		WHEN last_pts > 20 THEN 'star'
		WHEN last_pts > 15 THEN 'good'
		WHEN last_pts > 10 THEN 'average'
		ELSE 'bad'
	END::scoring_class AS scoring_class,
	years_since_last_season,
	is_active,
	current_season
FROM player_cumulative;

SELECT * FROM players WHERE current_season = 2022;
