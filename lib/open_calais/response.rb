# -*- encoding: utf-8 -*-
require 'stringex'

module OpenCalais
  class Response
    attr_accessor :raw, :language, :topics, :tags, :entities, :relations, :locations

    def initialize(response)
      @raw  = response

      @language = 'English'
      @topics    = []
      @tags      = []
      @entities  = []
      @relations = []
      @locations = []

      parse(response)
    end

    def humanize_topic(topic)
      begin
        topic.gsub('_', ' & ').titleize.remove_formatting
      rescue

      end
    end

    def importance_to_score(imp)
      case imp
      when 1 then 0.9
      when 2 then 0.7
      else 0.5
      end
    end

    def parse(response)
      begin
        r = response.body
        @language = r.doc.meta.language rescue nil
        @language = nil if @language == 'InputTextTooShort'

        r.each do |k,v|
          case v._typeGroup
          when 'topics'
            begin
              self.topics << {:name => humanize_topic(v.name), :score => v.score.to_f, :original => v.name}
            rescue
            end
          when 'socialTag'
            begin
              self.tags << {:name => v.name.gsub('_', ' and ').downcase, :score => importance_to_score(v.importance)}
            rescue
            end
          when 'entities'
            begin
              item = {:guid => k, :name => v.name, :type => v._type.remove_formatting.titleize, :score => 1.0}

              instances = Array(v.instances).select{|i| i.exact.downcase != item[:name].downcase }
              item[:matches] = instances if instances && instances.size > 0

              if OpenCalais::GEO_TYPES.include?(v._type)
                if (v.resolutions && v.resolutions.size > 0)
                  r = v.resolutions.first
                  item[:name]      = r.shortname || r.name
                  item[:latitude]  = r.latitude
                  item[:longitude] = r.longitude
                  item[:country]   = r.containedbycountry if r.containedbycountry
                  item[:state]     = r.containedbystate if r.containedbystate
                end
                self.locations << item
              else
                self.entities << item
              end
            rescue
            end
          when 'relations'
            begin
              item = v.reject{|k,v| k[0] == '_' || k == 'instances'} || {}
              item[:type] = v._type.remove_formatting.titleize
              self.relations << item
            rescue
            end
          end
        end

        # remove social tags which are in the topics list already
        if ! self.topics.nil?
          topic_names = self.topics.collect{|topic| topic[:name].downcase}
          self.tags.delete_if{|tag| topic_names.include?(tag[:name]) }
        end
      rescue Exception => e
        Rails.logger.info "OpenCalais Parse Error: #{e.message}"
      end
    end
  end
end
