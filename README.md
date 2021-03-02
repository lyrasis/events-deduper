# events-deduper

Deletes duplicate event relationships so you don't have to.

Latest version tested: `v2.8.1`

## Whaaaaat, why?

Right, this shouldn't be necessary. Having said that this can happen:

```
# abridged example:
[
    {
        "uri": "/repositories/2/events/1",
        "event_type": "component_transfer",
        "linked_records": [
            {
                "ref": "/repositories/18/resources/7046",
                "role": "source"
            },
            {
                "ref": "/repositories/18/archival_objects/962765",
                "role": "transfer"
            },
            {
                "ref": "/repositories/18/archival_objects/962765",
                "role": "transfer"
            },
            ... imagine 1000s of these for "962765" ...
```

This shows a __single__ event with __multiple__ linked record entries
to a __single__ archival object (962765) with the same role. These are
"duplicates", and they can wreak havoc with the indexer, gobbling
up all available memory (if there are many of them) as they are
redundantly resolved.

So until the causes of this are fully addressed this plugin can be used
to zap the duplicate linked records (deleting them from the database).
It does this by identifying duplicates based on record, event and role:

```
# three "duplicate" linked records
[id: 10, archival_object_id: 1, event_id: 1, role_id: 1]
[id: 11, archival_object_id: 1, event_id: 1, role_id: 1]
[id: 12, archival_object_id: 1, event_id: 1, role_id: 1]
```

The plugin will keep a survivor (the one with the lowest position) and
delete the others.

This query should help you find the problem:

```sql
SELECT
  archival_object_id,
  event_id,
  role_id,
  COUNT(*) as duplicates
FROM `event_link_rlshp`
GROUP BY archival_object_id, event_id, role_id
HAVING duplicates > 1
ORDER BY duplicates DESC;
```

## Warning

Hopefully you never run into an issue that requires this plugin, but if
you do you use it at your own risk! You should do something like this:

- take ArchivesSpace offline
- create a backup
- restore the backup in a test environment
- confirm / reproduce your event issue
- get a count of your event relationships: `SELECT count(*) FROM event_link_rlshp`
- enable the plugin in test
- fire up ArchivesSpace
- check how many records the plugin deleted (rerun query and subtract remaining from total)
- ArchivesSpace is indexing / working correctly?

Assuming things are now ok after testing:

- backup and restore the test database in production
- or, run with the plugin in production (then disable it)

---
