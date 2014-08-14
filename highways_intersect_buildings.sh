# usage: ./highways_intersect_buildings.sh <export> <drop>
# `export` and `drop` are optional

echo "
    CREATE TABLE _tmp_buildings AS
        SELECT id, tags, linestring as geom
        FROM ways
        WHERE tags ? 'building'
        AND NOT 'building=>no'::hstore <@ tags;
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
        AND NOT tags ? 'layer'
        AND NOT tags ? 'tunnel'
        AND NOT tags ? 'area'
        AND NOT 'highway=>footway'::hstore <@ tags
        AND NOT 'highway=>path'::hstore <@ tags
        AND NOT 'highway=>steps'::hstore <@ tags
        AND NOT 'highway=>living_street'::hstore <@ tags
        AND NOT 'highway=>pedestrian'::hstore <@ tags;
" | psql -U postgres -d osm

echo "
    CREATE INDEX _tmp_highways_gist
    ON _tmp_highways USING GIST(geom);
" | psql -U postgres -d osm

# the actual highways and buildings that intersect
# hwy, bldg
echo "
    CREATE TABLE highway_intersects_building AS
        SELECT hwy.id as hwy, bldg.id as bldg
        FROM _tmp_highways as hwy, _tmp_buildings as bldg
        WHERE st_intersects(hwy.geom, bldg.geom);
" | psql -U postgres -d osm

# drop temp tables
echo "
    DROP TABLE _tmp_buildings;
    DROP TABLE _tmp_highways;
" | psql -U postgres -d osm

if [ ! -x $1 ] && [ $1 == 'export' ]; then
    echo "
        COPY (select hwy, bldg from highway_intersects_building) to stdout DELIMITER ',' HEADER CSV;
    " | psql -U postgres -d osm > highway_intersects_building.csv

    echo "EXPORTED: highway_intersects_building.csv"
fi

if [ ! -x $2 ] && [ $2 == 'drop' ]; then
    echo "
        DROP TABLE highway_intersects_building;
    " | psql -U postgres -d osm

    echo "DROPPED: highway_intersects_building"
fi
