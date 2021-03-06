Darkswarm.factory 'Cart', (CurrentOrder, Variants, $timeout, $http, storage)->
  # Handles syncing of current cart/order state to server
  new class Cart
    dirty: false
    update_running: false
    update_enqueued: false
    order: CurrentOrder.order
    line_items: CurrentOrder.order?.line_items || []

    constructor: ->
      for line_item in @line_items
        line_item.variant.line_item = line_item
        Variants.register line_item.variant
        line_item.variant.extended_name = @extendedVariantName(line_item.variant)

    orderChanged: =>
      @unsaved()

      if !@update_running
        @scheduleUpdate()
      else
        @update_enqueued = true

    scheduleUpdate: =>
      if @promise
        $timeout.cancel(@promise)
      @promise = $timeout @update, 1000

    update: =>
      @update_running = true
      $http.post('/orders/populate', @data()).success (data, status)=>
        @saved()
        @update_running = false
        @popQueue() if @update_enqueued

      .error (response, status)=>
        @scheduleRetry(status)
        @update_running = false

    popQueue: =>
      @update_enqueued = false
      @scheduleUpdate()

    data: =>
      variants = {}
      for li in @line_items_present()
        variants[li.variant.id] =
          quantity: li.quantity
          max_quantity: li.max_quantity
      {variants: variants}

    scheduleRetry: (status) =>
      console.log "Error updating cart: #{status}. Retrying in 3 seconds..."
      $timeout =>
        console.log "Retrying cart update"
        @orderChanged()
      , 3000

    saved: =>
      @dirty = false
      $(window).unbind "beforeunload"

    unsaved: =>
      @dirty = true
      $(window).bind "beforeunload", ->
        t 'order_not_saved_yet'

    line_items_present: =>
      @line_items.filter (li)->
        li.quantity > 0

    total_item_count: =>
      @line_items_present().reduce (sum,li) ->
        sum = sum + li.quantity
      , 0

    empty: =>
      @line_items_present().length == 0

    total: =>
      @line_items_present().map (li)->
        li.variant.totalPrice()
      .reduce (t, price)->
        t + price
      , 0

    register_variant: (variant)=>
      exists = @line_items.some (li)-> li.variant == variant
      @create_line_item(variant) unless exists

    clear: ->
      @line_items = []
      storage.clearAll() # One day this will have to be moar GRANULAR

    create_line_item: (variant)->
      variant.extended_name = @extendedVariantName(variant)
      variant.line_item =
        variant: variant
        quantity: null
        max_quantity: null
      @line_items.push variant.line_item

    extendedVariantName: (variant) =>
      if variant.product_name == variant.name_to_display
        variant.product_name
      else
        name =  "#{variant.product_name} - #{variant.name_to_display}"
        name += " (#{variant.options_text})" if variant.options_text
        name
