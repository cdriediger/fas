module FasProtocol

  def self.generate(source_id, signal, data, arguments={})
    return JSON.generate(
        {'source_id' => source_id,
         'signal' => signal,
         'payload' => data,
         'arguments' => arguments}
    )
  end

  def self.decode(packet_json)
    begin
      data = JSON.parse(packet_json)
      data['arguments'] = {} unless data['arguments']
      return data
    rescue JSON::ParserError => e
      $Log.error("Can not parse JSON-Packet.\n  Error: #{e}\n  JSON: #{packet_json}")
      return false
    end
  end

end
