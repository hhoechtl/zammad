# Copyright (C) 2012-2014 Zammad Foundation, http://zammad-foundation.org/

class Locale < ApplicationModel

  def self.to_sync
    locales = Locale.where(active: true)
    if Rails.env.test?
      locales = Locale.where(active: true, locale: ['en-us', 'de-de'])
    end
    locales
  end

  def self.load
    url = 'https://i18n.zammad.com/api/v1/locales'

    result = UserAgent.get(
      url,
      {},
      {
        json: true,
      }
    )

    fail "Can't load locales from #{url}" if !result
    fail "Can't load locales from #{url}: #{result.error}" if !result.success?

    ActiveRecord::Base.transaction do
      result.data.each {|locale|
        exists = Locale.find_by(locale: locale['locale'])
        if exists
          exists.update(locale.symbolize_keys!)
        else
          Locale.create(locale.symbolize_keys!)
        end
      }
    end
    true
  end

end
