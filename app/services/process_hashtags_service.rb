# frozen_string_literal: true

require 'mecab'

class ProcessHashtagsService < BaseService
  def call(status, raw_tags = [])
    @status        = status
    @account       = status.account
    @raw_tags      = status.local? ? Extractor.extract_hashtags(status.text) : raw_tags
    @previous_tags = status.tags.to_a
    @current_tags  = []

    check_keyword_tags! if Rails.configuration.x.default_hashtag.present?
    assign_tags!
    update_featured_tags!
  end

  private

  def assign_tags!
    @status.tags = @current_tags = Tag.find_or_create_by_names(@raw_tags)
  end

  def update_featured_tags!
    return unless @status.distributable?

    added_tags = @current_tags - @previous_tags

    unless added_tags.empty?
      @account.featured_tags.where(tag_id: added_tags.map(&:id)).each do |featured_tag|
        featured_tag.increment(@status.created_at)
      end
    end

    removed_tags = @previous_tags - @current_tags

    unless removed_tags.empty?
      @account.featured_tags.where(tag_id: removed_tags.map(&:id)).each do |featured_tag|
        featured_tag.decrement(@status.id)
      end
    end
  end

  def check_keyword_tags!
    if @status.visibility == 'public' && @status.local? && !@status.reply? then
      tagger = MeCab::Tagger.new
      node = tagger.parseToNode(@status.text)

      status_words = []
      while node do
        features = node.feature.split(',')
        status_words.push(features[9]) if !features[9].blank?
        node = node.next
      end

      node = tagger.parseToNode(@status.spoiler_text)

      while node do
        features = node.feature.split(',')
        status_words.push(features[9]) if !features[9].blank?
        node = node.next
      end

      if status_words.length > 0 then
        @raw_tags << Rails.configuration.x.default_hashtag
        status_words.uniq.each do |word|
          @raw_tags << word
        end
      end
    end
  end
end
