class AddDefaultHashtag < ActiveRecord::Migration[6.1]
  def up
    tag = Tag.find_or_create_by_names(Rails.configuration.x.default_hashtag)
    status = Status.where(visibility: [:public], local: true)
    status.each do |s|
      if !s.tags.include?(tag[0]) then
        s.tags << tag
      end
    end
  end
end
