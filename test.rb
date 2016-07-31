def add_signal(signal, action)
  puts "Adding Signal: #{signal} => Action: #{action}"
end

signalhash = {'register'=>1,
               'ping reply'=>2,
               'become master'=>3,
               'client offline'=>4,
               'require plugin'=>5}

signalhash.each_pair do |signal, action|
  add_signal(signal, action)
end

signalhash.each_key do |signal|
  add_signal(signal, signalhash[signal])
end
