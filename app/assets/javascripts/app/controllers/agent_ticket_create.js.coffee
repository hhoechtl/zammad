class App.TicketCreate extends App.Controller
  elements:
    '.tabsSidebar'      : 'sidebar'

  events:
    'click .type-tabs .tab':  'changeFormType'
    'submit form':            'submit'
    'click .submit':          'submit'
    'click .cancel':          'cancel'

  constructor: (params) ->
    super

    # check authentication
    if !@authenticate()
      App.TaskManager.remove( @task_key )
      return

    # set title
    @form_meta = undefined

    # define default type
    @default_type = 'phone-in'

    # remember split info if exists
    split = ''
    if @ticket_id && @article_id
      split = "/#{@ticket_id}/#{@article_id}"

    # update navbar highlighting
    @navupdate '#ticket/create/id/' + @id + split

    @fetch(params)

    # lisen if view need to be rerendert
    @bind 'ticket_create_rerender', (defaults) =>
      @log 'notice', 'error', defaults
      @render(defaults)

  changeFormType: (e) =>
    type = $(e.target).data('type')
    if !type
      type = $(e.target).parent().data('type')
    @setFormTypeInUi(type)

  setFormTypeInUi: (type) =>

    # detect current form type
    if !type
      type = @el.find('.type-tabs .tab.active').data('type')
    if !type
      type = @default_type

    # reset all tabs
    tabs = @el.find('.type-tabs .tab')
    tabs.removeClass('active')
    tabIcons = @el.find('.type-tabs .tab .icon')
    tabIcons.addClass('gray')
    tabIcons.removeClass('white')

    # set active tab
    selectedTab = @el.find(".type-tabs .tab[data-type='#{type}']")
    selectedTab.addClass('active')
    selectedTabIcon = @el.find(".type-tabs .tab[data-type='#{type}'] .icon")
    selectedTabIcon.removeClass('gray')
    selectedTabIcon.addClass('white')

    # set form type attributes
    articleSenderTypeMap =
      'phone-in':
        sender:  'Customer'
        article: 'phone'
        title:   'Call Inbound'
        screen:  'create_phone_in'
      'phone-out':
        sender:  'Agent'
        article: 'phone'
        title:   'Call Outbound'
        screen:  'create_phone_out'
      'email-out':
        sender:  'Agent'
        article: 'email'
        title:   'Email'
        screen:  'create_email_out'
    @articleAttributes = articleSenderTypeMap[type]

    # update form
    @el.find('[name="formSenderType"]').val(type)

  meta: =>
    text = ''
    if @articleAttributes
      text = App.i18n.translateInline( @articleAttributes['title'] )
    title = @el.find('[name=title]').val()
    if title
      text = "#{text}: #{title}"
    meta =
      url:   @url()
      head:  text
      title: text
      id:    @id
      iconClass: 'pen'

  url: =>
    '#ticket/create/id/' + @id

  show: =>
    @navupdate '#'

  changed: =>
    formCurrent = @formParam( @el.find('.ticket-create') )
    diff = difference( @formDefault, formCurrent )
    return false if !diff || _.isEmpty( diff )
    return true

  release: =>
    # nothing

  autosave: =>
    update = =>
      data = @formParam( @el.find('.ticket-create') )
      diff = difference( @autosaveLast, data )
      if !@autosaveLast || ( diff && !_.isEmpty( diff ) )
        @autosaveLast = data
        @log 'notice', 'form hash changed', diff, data
        App.TaskManager.update( @task_key, { 'state': data })
    @interval( update, 3000, @id )

  # get data / in case also ticket data for split
  fetch: (params) ->

    # use cache
    cache = App.Store.get( 'ticket_create_attributes' )

    if cache && !params.ticket_id && !params.article_id

      # get edit form attributes
      @form_meta = cache.form_meta

      # load assets
      App.Collection.loadAssets( cache.assets )

      @render()
    else
      @ajax(
        id:    'ticket_create' + @task_key
        type:  'GET'
        url:   @apiPath + '/ticket_create'
        data:
          ticket_id: params.ticket_id
          article_id: params.article_id
        processData: true
        success: (data, status, xhr) =>

          # cache request
          App.Store.write( 'ticket_create_attributes', data )

          # get edit form attributes
          @form_meta = data.form_meta

          # load assets
          App.Collection.loadAssets( data.assets )

          # split ticket
          if data.split && data.split.ticket_id && data.split.article_id
            t = App.Ticket.find( params.ticket_id ).attributes()
            a = App.TicketArticle.find( params.article_id )

            # reset owner
            t.owner_id = 0
            t.customer_id_autocompletion = a.from
            t.subject = a.subject || t.title
            t.body = a.body

          # render page
          @render( options: t )
      )

  render: (template = {}) ->

    # get params
    params = {}
    if template && !_.isEmpty( template.options )
      params = template.options
    else if App.TaskManager.get(@task_key) && !_.isEmpty( App.TaskManager.get(@task_key).state )
      params = App.TaskManager.get(@task_key).state

    if params['form_id']
      @form_id = params['form_id']
    else
      @form_id = App.ControllerForm.formId()

    @html App.view('agent_ticket_create')(
      head:     'New Ticket'
      agent:    @isRole('Agent')
      admin:    @isRole('Admin')
      form_id:  @form_id
    )

    formChanges = (params, attribute, attributes, classname, form, ui) =>
      if @form_meta.dependencies && @form_meta.dependencies[attribute.name]
        dependency = @form_meta.dependencies[attribute.name][ parseInt(params[attribute.name]) ]
        if dependency

          for fieldNameToChange of dependency
            filter = []
            if dependency[fieldNameToChange]
              filter = dependency[fieldNameToChange]

            # find element to replace
            for item in attributes
              if item.name is fieldNameToChange
                item['filter'] = {}
                item['filter'][ fieldNameToChange ] = filter
                item.default = params[item.name]
                #if !item.default
                #  delete item['default']
                newElement = ui.formGenItem( item, classname, form )

            # replace new option list
            form.find('[name="' + fieldNameToChange + '"]').closest('.form-group').replaceWith( newElement )

    new App.ControllerForm(
      el:       @el.find('.ticket-form-top')
      form_id:  @form_id
      model:    App.Ticket
      screen:   'create_top'
      events:
        'change [name=customer_id]': @localUserInfo
      handlers: [
        formChanges
      ]
      filter:     @form_meta.filter
      autofocus: true
      params:    params
    )

    new App.ControllerForm(
      el:       @el.find('.article-form-top')
      form_id:  @form_id
      model:    App.TicketArticle
      screen:   'create_top'
      params:    params
    )
    new App.ControllerForm(
      el:       @el.find('.ticket-form-middle')
      form_id:  @form_id
      model:    App.Ticket
      screen:   'create_middle'
      events:
        'change [name=customer_id]': @localUserInfo
      handlers: [
        formChanges
      ]
      filter:     @form_meta.filter
      params:     params
      noFieldset: true
    )
    new App.ControllerForm(
      el:       @el.find('.ticket-form-bottom')
      form_id:  @form_id
      model:    App.Ticket
      screen:   'create_bottom'
      events:
        'change [name=customer_id]': @localUserInfo
      handlers: [
        formChanges
      ]
      filter:   @form_meta.filter
      params:   params
    )

    # set type selector
    @setFormTypeInUi( params['formSenderType'] )

    # remember form params of init load
    @formDefault = @formParam( @el.find('.ticket-create') )

    # show text module UI
    @textModule = new App.WidgetTextModule(
      el: @el.find('[data-name="body"]').parent()
    )

    new Sidebar(
      el:         @sidebar
      params:     @formDefault
      textModule: @textModule
    )

    $('#tags').tokenfield()

    # start auto save
    @autosave()

  localUserInfo: (e) =>

    params = App.ControllerForm.params( $(e.target).closest('form') )

    new Sidebar(
      el:         @sidebar
      params:     params
      textModule: @textModule
    )

  cancel: (e) ->
    e.preventDefault()
    @navigate '#'

  submit: (e) ->
    e.preventDefault()

    # get params
    params = @formParam(e.target)

    # fillup params
    if !params.title
      params.title = params.subject

    # create ticket
    ticket = new App.Ticket

    # find sender_id
    sender = App.TicketArticleSender.findByAttribute( 'name', @articleAttributes['sender'] )
    type   = App.TicketArticleType.findByAttribute( 'name', @articleAttributes['article'] )

    if params.group_id
      group  = App.Group.find( params.group_id )

    # create article
    if sender.name is 'Customer'
      params['article'] = {
        to:           (group && group.name) || ''
        from:         params.customer_id_autocompletion
        cc:           params.cc
        subject:      params.subject
        body:         params.body
        type_id:      type.id
        sender_id:    sender.id
        form_id:      @form_id
        content_type: 'text/html'
      }
    else
      params['article'] = {
        from:         (group && group.name) || ''
        to:           params.customer_id_autocompletion
        cc:           params.cc
        subject:      params.subject
        body:         params.body
        type_id:      type.id
        sender_id:    sender.id
        form_id:      @form_id
        content_type: 'text/html'
      }

    ticket.load(params)

    ticketErrorsTop = ticket.validate(
      screen: 'create_top'
    )
    ticketErrorsMiddle = ticket.validate(
      screen: 'create_middle'
    )
    ticketErrorsBottom = ticket.validate(
      screen: 'create_bottom'
    )

    article = new App.TicketArticle
    article.load( params['article'] )
    articleErrors = article.validate(
      screen: 'create_top'
    )

    # collect whole validation result
    errors = {}
    errors = _.extend( errors, ticketErrorsTop )
    errors = _.extend( errors, ticketErrorsMiddle )
    errors = _.extend( errors, ticketErrorsBottom )
    errors = _.extend( errors, articleErrors )

    # show errors in form
    if !_.isEmpty( errors )
      @log 'error', errors
      @formValidate(
        form:   e.target
        errors: errors
      )

    # save ticket, create article
    else

      # disable form
      @formDisable(e)
      ui = @
      ticket.save(
        done: ->

          # notify UI
          ui.notify
            type:    'success',
            msg:     App.i18n.translateInline( 'Ticket %s created!', @number ),
            link:    "#ticket/zoom/#{@id}"
            timeout: 4000,

          # close ticket create task
          App.TaskManager.remove( ui.task_key )

          # scroll to top
          ui.scrollTo()

          # access to group
          group_ids = App.Session.get('group_ids')
          if group_ids && _.contains( group_ids, @group_id )
            ui.navigate "#ticket/zoom/#{@id}"
            return

          # if not, show start screen
          ui.navigate "#"

        fail: ->
          ui.log 'save failed!'
          ui.formEnable(e)
      )

class Sidebar extends App.Controller
  constructor: ->
    super

    # load user
    if @params['customer_id']
      App.User.full( @params['customer_id'], @render )
      return

    # render ui
    @render()

  render: (user) =>

    items = []
    if user

      showCustomer = (el) =>
        # update text module UI
        if @textModule
          @textModule.reload(
            ticket:
              customer: user
          )

        new App.WidgetUser(
          el:       el
          user_id:  user.id
        )

      editCustomer = (e, el) =>
        new App.ControllerGenericEdit(
          id: @params.customer_id
          genericObject: 'User'
          screen: 'edit'
          pageData:
            title: 'Users'
            object: 'User'
            objects: 'Users'
        )
      items.push {
        head: 'Customer'
        name: 'customer'
        icon: 'person'
        actions: [
          {
            name:  'Edit Customer'
            class: 'glyphicon glyphicon-edit'
            callback: editCustomer
          },
        ]
        callback: showCustomer
      }

      if user.organization_id
        editOrganization = (e, el) =>
          new App.ControllerGenericEdit(
            id: user.organization_id
            genericObject: 'Organization'
            pageData:
              title: 'Organizations'
              object: 'Organization'
              objects: 'Organizations'
          )
        showOrganization = (el) =>
          new App.WidgetOrganization(
            el:               el
            organization_id:  user.organization_id
          )
        items.push {
          head: 'Organization'
          name: 'organization'
          icon: 'group'
          actions: [
            {
              name:     'Edit Organization'
              class:    'glyphicon glyphicon-edit'
              callback: editOrganization
            },
          ]
          callback: showOrganization
        }

    showTemplates = (el) =>

      # show template UI
      new App.WidgetTemplate(
        el:          el
        #template_id: template['id']
      )

    items.push {
      head: 'Templates'
      name: 'template'
      icon: 'templates'
      callback: showTemplates
    }

    new App.Sidebar(
      el:     @el
      items:  items
    )

class Router extends App.ControllerPermanent
  constructor: (params) ->
    super

    # create new uniq form id
    if !params['id']
      # remember split info if exists
      split = ''
      if params['ticket_id'] && params['article_id']
        split = "/#{params['ticket_id']}/#{params['article_id']}"

      id = Math.floor( Math.random() * 99999 )
      @navigate "#ticket/create/id/#{id}#{split}"
      return

    # cleanup params
    clean_params =
      ticket_id:  params.ticket_id
      article_id: params.article_id
      type:       params.type
      id:         params.id

    App.TaskManager.add( 'TicketCreateScreen-' + params['id'], 'TicketCreate', clean_params )

# create new ticket routes/controller
App.Config.set( 'ticket/create', Router, 'Routes' )
App.Config.set( 'ticket/create/', Router, 'Routes' )
App.Config.set( 'ticket/create/id/:id', Router, 'Routes' )

# split ticket
App.Config.set( 'ticket/create/:ticket_id/:article_id', Router, 'Routes' )
App.Config.set( 'ticket/create/id/:id/:ticket_id/:article_id', Router, 'Routes' )

# set new actions
App.Config.set( 'TicketCreate', { prio: 8003, parent: '#new', name: 'New Ticket', target: '#ticket/create', role: ['Agent'], divider: true }, 'NavBarRight' )
