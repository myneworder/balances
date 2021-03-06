@Balances.module 'AddressesApp.Index', (Index, App, Backbone, Marionette, $, _) ->

  #############################################################################
  # Layout
  #############################################################################

  class Index.Layout extends App.Views.Layout
    template: 'addresses/index/layout'
    tagName: 'section'

    regions:
      headerRegion: '#address-header-region'
      sidebarRegion: '#address-sidebar-region'
      formRegion: '#address-form-region'
      listRegion: '#address-list-region'
      listTotalRegion: '#address-list-total-region'

    ui:
      'btnNewAddress': '.add-new a'

    events:
      'click @ui.btnNewAddress': '_clickNewAddress'

    _clickNewAddress: (event) ->
      event.preventDefault()
      App.vent.trigger 'toggle:addresses:form'


  #############################################################################
  # Header
  #############################################################################

  class Index.Header extends App.Views.ItemView
    template: 'addresses/index/header'
    id: 'address-header'

    ui:
      'btnRefresh': '.refresh-data'

    events:
      'click @ui.btnRefresh': '_clickRefresh'

    initialize: ->
      @listenTo App.vent, 'updated:fiat:currency', @reRender

    serializeData: ->
      _.extend super,
        fiat_currency: App.fiatCurrency
        to_fiat_currency: "to_#{App.fiatCurrency.short_name}"

    _clickRefresh: (event) ->
      event.preventDefault()
      @_refreshStart()
      @model.fetch
        success: =>
          @collection.fetch
            success: =>
              @_refreshEnd()
            error: =>
              @_refreshEnd()
        error: =>
          @_refreshEnd()

    _refreshStart: ->
      @ui.btnRefresh.addClass 'is-loading'

    _refreshEnd: ->
      @ui.btnRefresh.removeClass 'is-loading'


  #############################################################################
  # Sidebar
  #############################################################################

  class Index.Sidebar extends App.Views.Layout
    template: 'addresses/index/sidebar'
    tagName: 'aside'
    id: 'address-sidebar'

    regions:
      balances: '#addresses-sidebar-balances-region'
      announcement: '#addresses-sidebar-announcement-region'

  class Index.SidebarBalances extends App.Views.Layout
    template: 'addresses/index/sidebar_balances'
    tagName: 'ul'
    id: 'currency-filters'

    ui:
      'filter': 'a'

    events:
      'click @ui.filter': '_clickFilter'

    modelEvents:
      'change': 'reRender'

    initialize: ->
      @listenTo App.vent, 'updated:fiat:currency', @reRender

    serializeData: ->
      _.extend super,
        fiat_currency: App.fiatCurrency
        balance: @model.get('totals')[App.fiatCurrency.short_name]
        balance_fiat_currency: "balance_#{App.fiatCurrency.short_name}"

    onShow: ->
      @$("a[data-filter=#{@collection.currencyFilter}]").parent().addClass 'current'

    _clickFilter: (event) ->
      event.preventDefault()
      $target = $(event.currentTarget)
      @collection.setCurrencyFilter $target.data('filter')
      @$('.current').removeClass 'current'
      $target.parent().addClass 'current'

    class Index.SidebarAnnouncement extends App.Views.Layout
      template: 'addresses/index/sidebar_announcement'
      id: 'announcement'

      ui:
        'btnClose': '.close-announcement'

      events:
        'click @ui.btnClose': '_close'

      _close: (event) ->
        event.preventDefault()
        @model.markAsRead
          success: (model, response, options) =>
            @$el.fadeOut 300, => @close()
          error: (model, response, options) ->
            alert 'There was an error :(. Please try again!'


  #############################################################################
  # List
  #############################################################################

  class Index.Empty extends App.Views.ItemView
    template: 'addresses/index/empty'
    tagName: 'tr'

  class Index.Item extends App.Views.ItemView
    getTemplate: ->
      if @model.get('edit_mode')
        'addresses/index/item_edit'
      else
        'addresses/index/item'
    tagName: 'tr'

    ui:
      'displayName': '.display-name'
      'inputName': 'input'
      'inputNotes': 'textarea'
      'btnSave': '.btn-save'
      'btnCancel': '.btn-cancel'
      'btnDelete': '.btn-delete'

    events:
      'keydown @ui.inputName': '_keydownInput'
      'click @ui.displayName': '_clickDisplayName'
      'click @ui.btnSave': '_clickSave'
      'click @ui.btnCancel': '_clickCancel'
      'click @ui.btnDelete': '_clickDelete'

    modelEvents:
      'change': 'reRender'

    serializeData: ->
      _.extend super,
        conversion: @_getConversion()
        integration_class: @model.get('integration')?.toLowerCase()
        formatted_created_at: moment(@model.get('created_at')).format('MMMM Do, YYYY')
        formatted_first_tx_at: if @model.get('first_tx_at') then moment(@model.get('first_tx_at')).format('MMMM Do, YYYY') else 'N/A'

    onShow: ->
      @$el.toggleClass 'is-editing', @model.get('edit_mode')
      # TODO @ui.inputName.focus() if @model.get('edit_mode')

    _getConversion: ->
      conversion = {}

      conversion.balance =
        if _.contains _.keys(gon.cryptocurrencies), @model.collection.conversion
          @model.get("balance_#{gon.cryptocurrencies[@model.collection.conversion].short_name}")
        else if _.contains _.keys(gon.fiat_currencies), @model.collection.conversion
          fiatCurrency = gon.fiat_currencies[@model.collection.conversion]
          fiatCurrency.symbol + @model.get("balance_#{fiatCurrency.short_name}")
        else
          @model.get('balance')

      conversion.short_name =
        if _.contains _.keys(gon.cryptocurrencies), @model.collection.conversion
          gon.cryptocurrencies[@model.collection.conversion].short_name_upper
        else if _.contains _.keys(gon.fiat_currencies), @model.collection.conversion
          ''
        else
          @model.get('short_name')

      conversion

    _keydownInput:
      _.debounce (event) ->
        if isEnterKey(event)
          @_save()
        else if isEscapeKey(event)
          @_reset()
      , 50

    _clickDisplayName: (event) ->
      event.preventDefault()
      @model.set edit_mode: true

    _clickSave: (event) ->
      event.preventDefault()
      @_save()

    _clickCancel: (event) ->
      event.preventDefault()
      @_reset()

    _clickDelete: (event) ->
      event.preventDefault()
      if confirm 'Are you sure you want to remove this address?'
        @model.destroy
          wait: true
          success: (model, response, options) ->
            App.currentUser.fetch()
          error: (model, response, options) ->
            alert 'Sorry, something went wrong. Please try again.'

    _save: ->
      name = _.str.trim @ui.inputName.val()
      notes = _.str.trim @ui.inputNotes.val()

      if @model.get('integration')?.length && not name.length
        alert 'Integrations must have a name.'
        return
      else if name is @model.get('name') and notes is @model.get('notes')
        @_reset()
        return
      else
        @model.save
          name: name
          notes: notes
        ,
          wait: true
          success: (model, response, options) =>
            @_reset()
            @$el.addClass('success-highlight')
            $.doTimeout 500, => @$el.removeClass('success-highlight')
          error: (model, response, options) ->
            alert 'Sorry, something went wrong. Please try again.'

    _reset: ->
      @model.set edit_mode: false

  class Index.List extends App.Views.CompositeView
    template: 'addresses/index/list'
    itemViewContainer: '#address-list'
    itemView: Index.Item
    emptyView: Index.Empty
    id: 'address-list-container'

    ui:
      'fiatCurrency': '#d-balances li:last-child a'
      'sortBy': '.sort-by'
      'sortByLabel': '.sort-by span'
      'conversionPrelabel': '.currency-type .conversion-prelabel'
      'conversionLabel': '.currency-type .conversion-label'

    events:
      'click #d-filters a': '_clickSort'
      'click #d-balances a': '_clickConversion'

    collectionEvents:
      'change:conversion': 'reRender'

    initialize: ->
      @listenTo App.vent, 'updated:fiat:currency', @_updateFiatCurrency

    serializeData: ->
      _.extend super,
        selected_currency: @collection.conversion
        fiat_currency: App.fiatCurrency

    onShow: ->
      @_updateSort()
      @_updateConversion()

    _getConversion: ->
      conversion = {}

      conversion.balance =
        if _.contains _.keys(gon.cryptocurrencies), @collection.conversion
          @model.get('totals')[gon.cryptocurrencies[@collection.conversion].short_name]
        else if _.contains _.keys(gon.fiat_currencies), @collection.conversion
          fiatCurrency = gon.fiat_currencies[@collection.conversion]
          fiatCurrency.symbol + @model.get('totals')[fiatCurrency.short_name]
        else
          @model.get('totals').btc

      conversion.short_name =
        if _.contains _.keys(gon.cryptocurrencies), @collection.conversion
          gon.cryptocurrencies[@collection.conversion].short_name_upper
        else if _.contains _.keys(gon.fiat_currencies), @collection.conversion
          gon.fiat_currencies[@collection.conversion].short_name_upper
        else
          gon.cryptocurrencies['btc'].short_name_upper

      conversion

    _clickSort: (event) ->
      event.preventDefault()
      @collection.setSortOrder $(event.currentTarget).data('sort')
      @_updateSort()
      @ui.sortBy.click() # Closes dropdown

    _clickConversion: (event) ->
      event.preventDefault()
      conversion = $(event.currentTarget).data('conversion')
      last_selected = if _.contains _.keys(gon.fiat_currencies), conversion
        'fiat'
      else
        conversion
      App.currentUser.save last_selected_conversion: last_selected
      @collection.setConversion conversion

    _updateFiatCurrency: ->
      if _.contains _.pluck(gon.fiat_currencies, 'short_name'), @collection.conversion
        @collection.setConversion App.fiatCurrency.short_name
      else
        @ui.fiatCurrency.attr(
          class: "icon #{App.fiatCurrency.short_name}"
          title: "Show values in #{App.fiatCurrency.name}"
          'data-conversion': App.fiatCurrency.short_name
        ).text "Fiat (#{App.fiatCurrency.short_name_upper})"

    _updateSort: ->
      $target = @$("#d-filters a[data-sort='#{@collection.sortOrder}']")
      @$('#d-filters .current').removeClass 'current'
      $target.addClass 'current'
      @ui.sortByLabel.text $target.text()

    _updateConversion: ->
      $target = @$("#d-balances a[data-conversion='#{@collection.conversion}']")
      @$('#d-balances .current').removeClass 'current'
      $target.addClass 'current'
      @ui.conversionPrelabel.toggle @collection.conversion isnt 'all'
      @ui.conversionLabel.text $target.text()

  class Index.ListTotal extends App.Views.ItemView
    template: 'addresses/index/list_total'
    id: 'address-list-total'
    tagName: 'table'

    collectionEvents:
      'change:conversion': 'reRender'

    modelEvents:
      'change': 'reRender'

    serializeData: ->
      _.extend super,
        conversion: @_getConversion()
        has_addresses: @collection.length
        has_btc: @collection.some (model) -> model.get('currency') is gon.cryptocurrencies['btc'].name
        has_doge: @collection.some (model) -> model.get('currency') is gon.cryptocurrencies['doge'].name
        has_ltc: @collection.some (model) -> model.get('currency') is gon.cryptocurrencies['ltc'].name
        has_str: @collection.some (model) -> model.get('currency') is gon.cryptocurrencies['str'].name
        has_vtc: @collection.some (model) -> model.get('currency') is gon.cryptocurrencies['vtc'].name

    # TODO: Do not duplicate this from Index>list
    _getConversion: ->
      conversion = {}

      conversion.balance =
        if _.contains _.keys(gon.cryptocurrencies), @collection.conversion
          @model.get('totals')[gon.cryptocurrencies[@collection.conversion].short_name]
        else if _.contains _.keys(gon.fiat_currencies), @collection.conversion
          fiatCurrency = gon.fiat_currencies[@collection.conversion]
          fiatCurrency.symbol + @model.get('totals')[fiatCurrency.short_name]
        else
          @model.get('totals').btc

      conversion.short_name =
        if _.contains _.keys(gon.cryptocurrencies), @collection.conversion
          gon.cryptocurrencies[@collection.conversion].short_name_upper
        else if _.contains _.keys(gon.fiat_currencies), @collection.conversion
          gon.fiat_currencies[@collection.conversion].short_name_upper
        else
          gon.cryptocurrencies['btc'].short_name_upper

      conversion

  #############################################################################
  # Form
  #############################################################################

  class Index.Form extends App.Views.ItemView
    template: 'addresses/index/form'
    id: 'address-form'
    tagName: 'article'

    ui:
      'balance': '.address-balance'
      'currencyType': '.currency-type'
      'inputAddress': '.address-public-address'
      'inputName': '.address-name'
      'hiddenAddress': '.hidden-public-address'
      'hiddenAddressFirstbits': '.hidden-public-firstbits'
      'btnQrScan': '.scan-qr'
      'btnImportCSV': '.import-csv'
      'btnSave': '.btn-save'
      'btnCancel': '.btn-cancel'
      'notices': '#address-notices'

    events:
      'keydown @ui.inputAddress': '_keydownInputAddress'
      'keydown @ui.inputName': '_keydownInputName'
      'paste @ui.inputAddress': '_pasteInputAddress'
      'cut @ui.inputAddress': '_cutInputAddress'
      'click @ui.btnSave': '_clickSave'
      'click @ui.btnCancel': '_clickCancel'

    modelEvents:
      'change:currency_image_path': '_changeCurrencyImage'
      'change:is_valid': '_changeIsValid'

    initialize: ->
      @listenTo App.vent, 'toggle:addresses:form', @_toggle
      @listenTo App.vent, 'scan:qr', @_scanQr

    onShow: ->
      @$('#m-scan-qr').on 'close', -> resetWebcam()

      # NOTE: Because the import screen is a reveal we need to manually bind
      #  to its events instead of relying on marionette.
      @$('#m-import-csv').on 'open', =>
        $('.btn-import').on 'click', (event) ->
          event.preventDefault()
          $input = $('#addresses-import')
          $input.click()
          $input.one 'change', ->
            $input.parent().submit()

      @$('#m-import-csv').on 'close', =>
        $('.btn-import').off 'click'

    _keydownInputAddress:
      _.debounce (event) ->
        return if isPasteKey(event) or
                  isSelectAllKey(event) or
                  isArrowKey(event)

        public_address = @ui.inputAddress.val()
        @model.set(public_address: public_address)

        @_clearErrors()

        if public_address.length is 0
          @model.set(currency_image_path: null)
        else if public_address.length < 27
          @model.fetchCurrency()
        else
          @model.fetchInfo
            error: =>
              @_addError()
      , 800

    _keydownInputName:
      _.debounce (event) ->
        if isEnterKey(event)
          @_save()
        else if isEscapeKey(event)
          @_reset(false)
      , 50

    _pasteInputAddress: (event) ->
      # Timeout so that the paste event completes and the input has data.
      $.doTimeout 50, =>
        public_address = @ui.inputAddress.val()
        @model.set(public_address: public_address)

        @_clearErrors()

        if public_address.length < 27 or public_address.length > 34
          @_addError()
          return

        @model.fetchInfo
          error: =>
            @_addError()

    _cutInputAddress: (event) ->
      # Timeout so that the cut event completes and the input has data.
      $.doTimeout 50, =>
        if @ui.inputAddress.val().length is 0
          @model.clear()
          @_clearErrors()

    _toggle: ->
      @$el.slideToggle()

    _scanQr: ->
      public_address = @ui.inputAddress.val()
      @model.set(public_address: public_address)

      @_clearErrors()

      if public_address.length < 27 or public_address.length > 34
        @_addError()
        return

      @model.fetchInfo
        error: =>
          @_addError()

    _clickSave: (event) ->
      event.preventDefault()
      @_save()

    _clickCancel: (event) ->
      event.preventDefault()
      @_reset(false)

    _changeCurrencyImage: ->
      if @model.get('currency_image_path')
        @ui.currencyType.addClass('is-filled').html $('<img />',
          src: @model.get('currency_image_path')
          alt: @model.get('currency'))
      else
        @ui.currencyType.removeClass('is-filled').html('')

    _changeIsValid: ->
      if @model.get('is_valid')
        @ui.btnQrScan.hide()
        @ui.btnImportCSV.hide()
        @ui.btnSave.css('display', 'inline-block')
        @ui.btnCancel.css('display', 'inline-block')
        @ui.hiddenAddressFirstbits.text @model.get('public_address').slice(0,8)
        @ui.inputAddress
          .addClass('is-valid')
          .css('width', @ui.hiddenAddressFirstbits.outerWidth())
          .prop('disabled', true)
        @ui.balance.text("#{@model.get('balance')} #{@model.get('short_name')}").show()
        inputNameWidth = @$('.address-input').outerWidth() - @ui.inputAddress.outerWidth() - @ui.balance.outerWidth() - 10
        @ui.inputName.css('width', inputNameWidth).show().focus()
      else
        @model.clear()
        @_addError()

    _save: ->
      @ui.notices.hide().empty()

      balance = @ui.balance.text()
      name = _.str.trim @ui.inputName.val()

      @model.set
        balance: balance.slice(0, _.indexOf(balance, ' ')).replace(/,/g, '')
        name: name
        display_name: name or @model.get('public_address')

      @collection.create @model.attributes,
        wait: true
        success: (model, response, options) =>
          @_reset()

          # Refresh the user
          App.currentUser.fetch()

          # Show success message
          @ui.notices.show()
          $notice = $('<li/>', class: 'success').text 'Address successfully added'
          @ui.notices.append $notice
          $.doTimeout 5000, =>
            @ui.notices.fadeOut 300, =>
              $.doTimeout 50, => @ui.notices.empty()

        error: (model, response, options) =>
          @ui.notices.show()
          _.each JSON.parse(response.responseText).errors, (msg, key) =>
            $notice = $('<li/>', class: 'error').text "#{_.str.titleize(_.str.humanize(key))} #{msg}"
            @ui.notices.append $notice

    _addError: ->
      @ui.inputAddress.addClass 'is-invalid'

    _clearErrors: ->
      @ui.inputAddress.removeClass 'is-invalid'

    _reset: (clearAddress = true) ->
      @model.clear()
      @_clearErrors()
      @ui.notices.hide().empty()
      @ui.btnQrScan.show()
      @ui.btnImportCSV.show()
      @ui.btnSave.hide()
      @ui.btnCancel.hide()
      @ui.inputName.val('').hide()
      @ui.balance.text('').hide()
      @ui.inputAddress.removeClass('is-valid').prop('disabled', false).css('width', '100%')
      @ui.inputAddress.val('') if clearAddress
