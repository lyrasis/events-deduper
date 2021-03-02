# frozen_string_literal: true

# DELETE DUPLICATE EVENT RELATIONSHIPS

Log.info 'Events relationship deduper to the rescue! (deletes duplicates if present =)'

# we are deduping repeat occurences of each ${type}_id
# to the SAME event_id if they have the same role_id
# i.e. these are considered a duplicate:
# [id: 10, archival_object_id: 1, event_id: 1, role_id: 1]
# [id: 11, archival_object_id: 1, event_id: 1, role_id: 1]
# [id: 12, archival_object_id: 1, event_id: 1, role_id: 1]
dupes = {
  accession_id: [],
  archival_object_id: [],
  digital_object_id: [],
  digital_object_component_id: [],
  resource_id: []
}

ArchivesSpaceService.loaded_hook do
  DB.open do |db|
    dupes.keys.each do |type_id|
      dupe_event_relationships = db[:event_link_rlshp]
                                 .exclude(type_id => nil)
                                 .group_and_count(:event_id, type_id, :role_id)
                                 .having { count.function.* > 1 }
                                 .all.map do |event_rlshp|
        {
          event_id: event_rlshp[:event_id],
          type_id => event_rlshp[type_id],
          role_id: event_rlshp[:role_id]
        }
      end
      dupes[type_id] = dupe_event_relationships
    end

    dupes.each do |type_id, dupe_event_relationships|
      next unless dupe_event_relationships.any?

      dupe_event_relationships.each do |dupe_event_relationship|
        ids = db[:event_link_rlshp]
              .where(
                event_id: dupe_event_relationship[:event_id],
                type_id => dupe_event_relationship[type_id],
                role_id: dupe_event_relationship[:role_id]
              )
              .order(:aspace_relationship_position)
              .all.map do |e|
          e[:id]
        end
        ids.shift # the survivor is the lowest positioned event relationship
        ids.each { |id| db[:event_link_rlshp].filter(id: id).delete }
      end
    end
  end
end

dupes = nil
