require 'net/smtp'

module Email

  def init_plugin(mode)
    @name = "Email"
    @comment = "Send and Recive Emails"
	@signals = {'send_email'=>self.method(:send_email)}
    @jobs = []
  end

  def send_email(id, payload, arguments=false)
    now = Time.now
    unless arguments
      puts "Email.send_email needs Arguments"
      return
    end
    msgstr = <<END_OF_MESSAGE
From: Automation system <automation@driediger.eu>
To: <#{arguments['email_address']}>
Subject: #{arguments['email_subject']}
Date: #{now.strftime("%a, %d %b %Y, %H:%M:%S %z")}
Message-Id: <unique.message.id.string@example.com>

Recived new Payload:
#{payload}
Arguments:
#{arguments}
End of Payload
END_OF_MESSAGE

    Net::SMTP.start(@config['smtp_server'], @config['smtp_port']) do |smtp|
      smtp.send_message msgstr,
      arguments['email_address'],
      arguments['email_address']
    end
  end

end
