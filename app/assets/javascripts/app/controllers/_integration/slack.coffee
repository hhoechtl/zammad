class Index extends App.ControllerIntegrationBase
  featureIntegration: 'slack_integration'
  featureName: 'Slack'
  featureConfig: 'slack_config'
  description: [
    ['This service sends notifications to your %s channel.', 'Slack']
    ['To setup this Service you need to create a new |"Incoming webhook"| in your %s integration panel, and enter the Webhook URL below.', 'Slack']
  ]

  render: =>
    super

    params = App.Setting.get(@featureConfig)
    if params && params.items
      params = params.items[0] || {}

    options =
      create: '1. Ticket Create'
      update: '2. Ticket Update'
      reminder_reached: '3. Ticket Reminder Reached'
      escalation: '4. Ticket Escalation'
      escalation_warning: '5. Ticket Escalation Warning'

    configureAttributes = [
      { name: 'types',    display: 'Trigger',  tag: 'checkbox', options: options, 'null': false, class: 'vertical', note: 'Where notification is sent.' },
      { name: 'group_id', display: 'Group',    tag: 'select', relation: 'Group', multiple: true, 'null': false, note: 'Only for this groups.' },
      { name: 'webhook',  display: 'Webhook',  tag: 'input', type: 'text', limit: 200, 'null': false, placeholder: 'https://hooks.slack.com/services/...' },
      { name: 'username', display: 'Username', tag: 'input', type: 'text', limit: 100, 'null': false, placeholder: 'username' },
      { name: 'channel',  display: 'Channel',  tag: 'input', type: 'text', limit: 100, 'null': true, placeholder: '#channel' },
    ]

    settings = []
    for item in configureAttributes
      setting =
        options:
          form: [item]
        name: item.name
        description: item.note || ''
        title: item.display
      settings.push setting

    formEl = $( App.view('settings/form')(
      settings: settings
    ))

    for setting in settings
      configure_attribute = setting.options['form']
      configure_attribute[0].display = ''
      value = params[setting.name]
      localParams = {}
      localParams[setting.name] = value
      new App.ControllerForm(
        el: formEl.find("[data-name=#{setting.name}]")
        model: { configure_attributes: configure_attribute, className: '' }
        params: localParams
      )

    @$('.js-form').html(formEl)

    new App.HttpLog(
      el: @$('.js-log')
      facility: 'slack_webhook'
    )

class State
  @current: ->
    App.Setting.get('slack_integration')

App.Config.set(
  'IntegrationSlack'
  {
    name: 'Slack'
    target: '#system/integration/slack'
    description: 'A team communication tool for the 21st century.'
    controller: Index
    state: State
  }
  'NavBarIntegrations'
)