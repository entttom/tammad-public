# Testdaten für die lokale Zammad-Testinstanz von Tammad.
# Wird von setup.sh im Rails-Container ausgeführt:
#   ADMIN_PASSWORD=... AGENT_PASSWORD=... rails r /tmp/seed.rb
# Kann erneut ausgeführt werden (find_or_create; Tickets nur beim ersten Lauf).
#
# Enthält bewusst Grenzfälle, die die App abdecken muss:
# - Kunde ohne Namen, Gruppe mit note = nil, 15 Gruppen (Pagination), inaktive Gruppe
# - eigene States "in Bearbeitung" (Typ open) und "Wartet auf Kunde" (Typ pending reminder)
# - SLA: Priorität "3 high" eskaliert eine Minute nach Erstellung
# - HTML-Mail mit eingebettetem Bild (cid → /api/v1/ticket_attachment/…?view=inline),
#   Script-Tag, Link, Zitat und PDF-Anhang mit "/" im Dateinamen
# - überfällige Wiedervorlagen, Mention (Abonniert), nicht zugewiesenes Ticket
# - 24 weitere Tickets für die Pagination (Seitengröße in der App: 15)

require 'zlib'

UserInfo.current_user_id = 1

def png(width = 320, height = 160, rgb = [30, 90, 160])
  raw = (0...height).map { "\x00".b + rgb.pack('C*') * width }.join
  chunk = lambda do |type, data|
    [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
  end
  "\x89PNG\r\n\x1a\n".b +
    chunk.call('IHDR'.b, [width, height, 8, 2, 0, 0, 0].pack('NNCCCCC')) +
    chunk.call('IDAT'.b, Zlib::Deflate.deflate(raw)) +
    chunk.call('IEND'.b, ''.b)
end

# --- System settings ---------------------------------------------------------
Setting.set('system_init_done', true)
Setting.set('fqdn', 'localhost:8080')
Setting.set('http_type', 'http')
Setting.set('api_password_access', true)
Setting.set('api_token_access', true)
Setting.set('system_online_service', false)

org = Organization.find_or_create_by!(name: 'Tammad Test GmbH') { |o| o.domain = 'tammad.test' }

# --- Groups (> 10 to exercise pagination) -------------------------------------
support = Group.find_or_create_by!(name: 'Support') { |g| g.active = true }
(1..12).each { |i| Group.find_or_create_by!(name: format('Gruppe %02d', i)) { |g| g.active = true } }
Group.find_or_create_by!(name: 'Archiv (inaktiv)') { |g| g.active = false }
Group.all.each { |g| g.update!(note: nil) if g.name == 'Gruppe 01' } # null note regression case

admin_role = Role.find_by!(name: 'Admin')
agent_role = Role.find_by!(name: 'Agent')
customer_role = Role.find_by!(name: 'Customer')

def upsert_user(login:, **attrs)
  user = User.find_by(login: login) || User.new(login: login)
  user.assign_attributes(attrs)
  user.save!
  user
end

# Login ohne "@": der Simulator nutzt eine deutsche Hardware-Tastatur, auf der
# sich "@" per simulierter Eingabe nicht tippen lässt. Die E-Mail funktioniert
# in Zammad ebenfalls als Benutzername.
User.find_by(login: 'admin@tammad.test')&.update!(login: 'tammadadmin')
admin = upsert_user(login: 'tammadadmin', firstname: 'Ada', lastname: 'Admin', email: 'admin@tammad.test',
                    password: ENV.fetch('ADMIN_PASSWORD'), active: true, roles: [admin_role, agent_role],
                    organization: org)
agent = upsert_user(login: 'agent@tammad.test', firstname: 'Bruno', lastname: 'Agent', email: 'agent@tammad.test',
                    password: ENV.fetch('AGENT_PASSWORD'), active: true, roles: [agent_role])
access = Group.where(active: true).to_h { |g| [g.name, ['full']] }
admin.group_names_access_map = access
agent.group_names_access_map = access

customer = upsert_user(login: 'kunde@tammad.test', firstname: 'Alex', lastname: 'Muster', email: 'kunde@tammad.test',
                       roles: [customer_role], organization: org)
nameless = upsert_user(login: 'nameless@tammad.test', firstname: '', lastname: '', email: 'nameless@tammad.test',
                       roles: [customer_role])

# --- States and priorities ----------------------------------------------------
open_type = Ticket::StateType.find_by!(name: 'open')
pending_type = Ticket::StateType.find_by!(name: 'pending reminder')
in_progress = Ticket::State.find_or_create_by!(name: 'in Bearbeitung') do |s|
  s.state_type = open_type
  s.active = true
end
waiting_customer = Ticket::State.find_or_create_by!(name: 'Wartet auf Kunde') do |s|
  s.state_type = pending_type
  s.active = true
  s.ignore_escalation = true
end
state = ->(name) { Ticket::State.find_by!(name: name) }
priority = ->(name) { Ticket::Priority.find_by!(name: name) }

# --- SLA: "3 high" tickets escalate one minute after creation ------------------
calendar = Calendar.find_by(default: true) || Calendar.first
Sla.find_or_create_by!(name: 'Tammad Test SLA') do |sla|
  sla.calendar = calendar
  sla.first_response_time = 1
  sla.condition = { 'ticket.priority_id' => { 'operator' => 'is', 'value' => [priority.call('3 high').id.to_s] } }
end
# Make the SLA effective around the clock so the test does not depend on the time of day.
if calendar
  hours = %w[mon tue wed thu fri sat sun].to_h do |day|
    [day, { 'active' => true, 'timeframes' => [['00:00', '23:59']] }]
  end
  calendar.update!(business_hours: hours)
end

# --- Tickets ------------------------------------------------------------------
def create_ticket(title:, group:, customer:, owner: nil, state:, priority:, body:, content_type: 'text/plain',
                  pending_time: nil, created_by:, sender: 'Customer', type: 'email', from: nil)
  ticket = Ticket.create!(title: title, group: group, customer: customer, owner: owner || User.find(1),
                          state: state, priority: priority, pending_time: pending_time,
                          created_by_id: created_by.id, updated_by_id: created_by.id)
  article = Ticket::Article.create!(ticket: ticket, type: Ticket::Article::Type.find_by!(name: type),
                                    sender: Ticket::Article::Sender.find_by!(name: sender),
                                    from: from || "#{customer.fullname} <#{customer.email}>",
                                    to: 'support@tammad.test', subject: title, body: body,
                                    content_type: content_type, internal: false,
                                    created_by_id: created_by.id, updated_by_id: created_by.id)
  [ticket, article]
end

if Ticket.where(title: 'Drucker im Empfang ist offline').none?
  html = <<~HTML
    <p>Hallo Team,</p>
    <p>der Drucker &amp; Scanner im Empfang ist seit heute Morgen offline. Hier ein Screenshot:</p>
    <p><img src="cid:screenshot@tammad.test" alt="Screenshot"></p>
    <p>Mehr dazu im <a href="https://docs.zammad.org">Handbuch</a>.</p>
    <script>document.body.innerHTML = '<h1>SCRIPT RAN</h1>'</script>
    <blockquote>Zitat aus einer früheren Nachricht</blockquote>
  HTML
  ticket, article = create_ticket(title: 'Drucker im Empfang ist offline', group: support, customer: customer,
                                  owner: admin, state: state.call('open'), priority: priority.call('2 normal'),
                                  body: html, content_type: 'text/html', created_by: customer)
  Store.create!(object: 'Ticket::Article', o_id: article.id, data: png, filename: 'screenshot.png',
                preferences: { 'Content-Type' => 'image/png', 'Mime-Type' => 'image/png',
                               'Content-ID' => 'screenshot@tammad.test', 'Content-Disposition' => 'inline' },
                created_by_id: 1)
  Store.create!(object: 'Ticket::Article', o_id: article.id, data: "%PDF-1.4\n% Tammad test\n",
                filename: 'Rechnung 03/2026.pdf',
                preferences: { 'Content-Type' => 'application/pdf', 'Mime-Type' => 'application/pdf' },
                created_by_id: 1)
  Ticket::Article.create!(ticket: ticket, type: Ticket::Article::Type.find_by!(name: 'note'),
                          sender: Ticket::Article::Sender.find_by!(name: 'Agent'), from: 'Ada Admin',
                          body: 'Interne Notiz: Techniker ist informiert. VERTRAULICH', content_type: 'text/plain',
                          internal: true, created_by_id: admin.id, updated_by_id: admin.id)

  create_ticket(title: 'VPN-Zugang für neue Mitarbeiterin', group: support, customer: nameless, owner: agent,
                state: in_progress, priority: priority.call('2 normal'), body: 'Bitte VPN einrichten.',
                created_by: nameless)
  create_ticket(title: 'Rückruf zur Rechnung (wartet auf Kunde, überfällig)', group: Group.find_by!(name: 'Gruppe 03'),
                customer: customer, owner: admin, state: waiting_customer, priority: priority.call('1 low'),
                pending_time: 2.hours.ago, body: 'Kunde meldet sich zurück.', created_by: customer)
  create_ticket(title: 'Lizenz verlängern (Erinnerung überfällig)', group: support, customer: customer, owner: admin,
                state: state.call('pending reminder'), priority: priority.call('2 normal'),
                pending_time: 1.day.ago, body: 'Erinnerung zur Lizenzverlängerung.', created_by: customer)
  create_ticket(title: 'Newsletter abbestellen (Erinnerung in Zukunft)', group: support, customer: customer,
                owner: admin, state: state.call('pending reminder'), priority: priority.call('1 low'),
                pending_time: 3.days.from_now, body: 'Bitte abmelden.', created_by: customer)
  create_ticket(title: 'Server down – dringend', group: support, customer: customer, owner: agent,
                state: state.call('open'), priority: priority.call('3 high'),
                body: 'Produktivserver antwortet nicht. C++ & Java Dienste betroffen; bitte prüfen!', created_by: customer)
  create_ticket(title: 'Nicht zugewiesene Anfrage', group: support, customer: nameless, owner: nil,
                state: state.call('new'), priority: priority.call('2 normal'), body: 'Wer kümmert sich?',
                created_by: nameless)
  mentioned, = create_ticket(title: 'Abonniertes Ticket (Mention)', group: support, customer: customer, owner: agent,
                             state: state.call('open'), priority: priority.call('2 normal'),
                             body: 'Bitte auf dem Laufenden halten.', created_by: customer)
  Mention.create!(mentionable: mentioned, user: admin, created_by_id: admin.id, updated_by_id: admin.id)
  create_ticket(title: 'Erledigte Anfrage', group: support, customer: customer, owner: admin,
                state: state.call('closed'), priority: priority.call('2 normal'), body: 'Erledigt.',
                created_by: customer)

  # Enough additional tickets to page through (page size in the app: 15).
  (1..24).each do |i|
    create_ticket(title: format('Massenticket %02d', i), group: Group.find_by!(name: format('Gruppe %02d', (i % 12) + 1)),
                  customer: customer, owner: i.even? ? admin : agent, state: state.call(i % 3 == 0 ? 'closed' : 'open'),
                  priority: priority.call('2 normal'), body: "Automatisch erzeugtes Ticket #{i}.", created_by: customer)
  end
end

# --- Ausgehende E-Mail-Adresse (sonst lehnt Zammad E-Mail-Antworten ab) --------
# Es gibt keinen Mailserver: Zammad legt den Artikel an und vermerkt den
# fehlgeschlagenen Versand als Notiz – für App-Tests genügt das.
channel = Channel.find_by(area: 'Email::Account') ||
          Channel.create!(area: 'Email::Account', group: support, active: true,
                          options: { inbound: { adapter: 'null', options: {} }, outbound: { adapter: 'sendmail', options: {} } })
email_attrs = { email: 'support@tammad.test', channel: channel, active: true }
email_attrs[EmailAddress.column_names.include?('realname') ? :realname : :name] = 'Tammad Support'
email_address = EmailAddress.find_by(email: 'support@tammad.test') || EmailAddress.create!(email_attrs)
Group.where(active: true).find_each { |g| g.update!(email_address: email_address) }

TextModule.find_or_create_by!(name: 'Begrüßung') do |m|
  m.keywords = 'hallo'
  m.content = 'Guten Tag,<br><br>vielen Dank für Ihre Nachricht.'
  m.active = true
end
TextModule.find_or_create_by!(name: 'Abschluss') do |m|
  m.keywords = 'gruss'
  m.content = 'Mit freundlichen Grüßen<br>Ihr Support-Team'
  m.active = true
end

token = Token.find_by(user: admin, action: 'api', name: 'tammad-test') ||
        Token.create!(user: admin, action: 'api', name: 'tammad-test', persistent: true,
                      preferences: { permission: %w[admin ticket.agent user_preferences] })

puts "SEED_OK tickets=#{Ticket.count} groups=#{Group.count} states=#{Ticket::State.count}"
puts "API_TOKEN=#{token.token}"
