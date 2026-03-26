CREATE TYPE scd_type AS (
	scoring_class scoring_class,
	is_active BOOLEAN,
	start_season INTEGER,
	end_season INTEGER
);

WITH last_season_scd AS (
	SELECT * FROM players_scd
	WHERE current_season = 2021
	AND end_season = 2021
),
	historical_scd AS (
	SELECT * FROM players_scd
	WHERE current_season = 2021
	AND end_season < 2021
),
	this_season_scd AS (
	SELECT * FROM players
	WHERE current_season = 2022
),
	unchaged_records AS (
	SELECT ts.player_name,
	   ts.scoring_class,
	   ts.is_active,
	   ls.start_season,
	   ts.current_season as end_season
	FROM last_season_scd ls
	JOIN this_season_scd ts
	ON ls.player_name = ts.player_name
	WHERE ls.scoring_class = ts.scoring_class
	AND ls.is_active = ts.is_active
	),
	changed_records AS (
	SELECT 
	   ts.player_name,
	   UNNEST(ARRAY[
		ROW(
		   ls.scoring_class,
		   ls.is_active,
		   ls.start_season,
		   ls.end_season
		)::scd_type,
		ROW(
		   ts.scoring_class,
		   ts.is_active,
		   ts.current_season,
		   ts.current_season
		)::scd_type
	   ]) as records
	FROM last_season_scd ls
	RIGHT JOIN this_season_scd ts
	ON ls.player_name = ts.player_name
	WHERE ls.scoring_class <> ts.scoring_class
	OR ls.is_active <> ts.is_active
	OR ls.player_name IS NULL
	),
	unnested_changed_records AS (
	SELECT player_name,
		   (records::scd_type).scoring_class,
		   (records::scd_type).is_active,
		   (records::scd_type).start_season,
		   (records::scd_type).end_season
	FROM changed_records
	),
	new_records AS (
	SELECT ts.player_name,
		   ts.scoring_class,
		   ts.is_active,
		   ts.current_season as start_season,
		   ts.current_season as end_season
	FROM this_season_scd ts
	LEFT JOIN last_season_scd ls
	ON ts.player_name = ls.player_name
	WHERE ls.player_name IS NULL
	)
SELECT * FROM historical_scd

UNION ALL

SELECT * FROM unchanged_records

UNION ALL

SELECT * FROM unnested_changed_records

UNION ALL

SELECT * FROM new_records;