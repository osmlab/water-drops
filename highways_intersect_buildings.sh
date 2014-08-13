echo "
    CREATE TABLE _tmp_buildings AS
        SELECT id, tags, linestring as geom
        FROM ways
        WHERE tags ? 'building'
        AND NOT '\"building\"=>\"no\"'::hstore <@ tags;
" | psql -U postgres -d osm

echo "
    CREATE INDEX _tmp_buildings_gist
    ON _tmp_buildings USING GIST(geom);
" | psql -U postgres -d osm

echo "
    CREATE TABLE _tmp_highways AS
        SELECT id, linestring as geom
        FROM ways
        WHERE tags ? 'highway'
        AND NOT tags ? 'layer';
" | psql -U postgres -d osm

echo "
    CREATE INDEX _tmp_highways_gist
    ON _tmp_highways USING GIST(geom);
" | psql -U postgres -d osm

echo "
    CREATE TABLE highway_intersects_building AS
        SELECT hwy.id as hwy, bldg.id as bldg
        FROM _tmp_highways as hwy, _tmp_buildings as bldg
        WHERE st_intersects(hwy.geom, bldg.geom);
" | psql -U postgres -d osm
