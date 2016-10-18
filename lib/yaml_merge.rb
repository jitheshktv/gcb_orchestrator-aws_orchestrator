require 'yaml'

class YamlMerger

  ##
  # input the two actual YAML strings, and get back the actual YAML string of the merge
  # fails out if any collisions
  #
  def merge(yaml1, yaml2)
    hash1 = YAML.load yaml1
    hash2 = YAML.load yaml2

    if hash1.nil?
      hash1 = {}
    end

    if hash2.nil?
      hash2 = {}
    end

    merged_hash = hash1.merge(hash2) do |key, oldval, newval|
      if oldval != newval
        raise "Collision on key: #{key} for |#{oldval}| v. |#{newval}| and types: #{oldval.class} and #{newval.class}"
      else
        oldval
      end
    end

    YAML.dump merged_hash
  end
end

