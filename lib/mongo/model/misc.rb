module Mongo::Model::Misc
  def update_created_at; self.created_at = Time.now.utc end
  def update_updated_at; self.updated_at = Time.now.utc end

  def update_timestamps
    now = Time.now.utc
    self.created_at ||= now
    self.updated_at = now
  end

  def _cache
    @_cache ||= {}
  end

  def dom_id
    # new_record? ? "new_#{self.class.name.underscore}" : to_param
    to_param
  end

  def to_param
    id.try :to_s
  end

  def reload
    obj = self.class.by_id!(id || raise("can't reload new document (#{self})!"))
    instance_variables.each{|n| remove_instance_variable n}
    obj.instance_variables.each do |n|
      instance_variable_set n, obj.instance_variable_get(n)
    end
    nil
  end

  def original
    unless _cache[:original_cached]
      _cache[:original_cached] = true
      _cache[:original] = id && self.class.by_id(id)
    end
    _cache[:original]
  end

  module ClassMethods
    def timestamps!
      attr_accessor :created_at, :updated_at
      before_create :update_created_at
      before_save :update_updated_at
    end

    def create_index *args
      collection.create_index *args
    end
  end
end