af = Package['aldeed:autoform']
c2 = Package['aldeed:collection2']
SimpleSchema = Package['aldeed:simple-schema']?.SimpleSchema

defaults =
  removed: 'removed'
  removedAt: 'removedAt'
  removedBy: 'removedBy'
  restoredAt: 'restoredAt'
  restoredBy: 'restoredBy'
  systemId: '0'

behaviour = (options = {}) ->
  check options, Object

  {removed, removedAt, removedBy, restoredAt, restoredBy, systemId} =
    _.defaults options, @options, defaults

  if c2?
    afDefinition = autoform:
      omit: true

    addAfDef = (definition) ->
      _.extend definition, afDefinition

    definition = {}

    def = definition[removed] =
      optional: true
      type: Boolean

    addAfDef def if af?

    if removedAt
      def = definition[removedAt] =
        denyInsert: true
        optional: true
        type: Date

      addAfDef def if af?

    regEx = new RegExp "(#{SimpleSchema.RegEx.Id.source})|^#{systemId}$"

    if removedBy
      def = definition[removedBy] =
        denyInsert: true
        optional: true
        regEx: regEx
        type: String

      addAfDef def if af?

    if restoredAt
      def = definition[restoredAt] =
        denyInsert: true
        optional: true
        type: Date

      addAfDef def if af?

    if restoredBy
      def = definition[restoredBy] =
        denyInsert: true
        optional: true
        regEx: regEx
        type: String

      addAfDef def if af?

    @collection.attachSchema new SimpleSchema definition

  beforeFindHook = (userId = systemId, selector = {}, options = {}) ->
    isSelectorId = _.isString(selector) or '_id' of selector
    unless options.removed or isSelectorId or selector[removed]?
      selector[removed] =
        $exists: false

    @args[0] = selector
    return

  @collection.before.find beforeFindHook
  @collection.before.findOne beforeFindHook

  @collection.before.update (userId = systemId, doc, fieldNames, modifier,
    options) ->

    $set = modifier.$set ?= {}
    $unset = modifier.$unset ?= {}

    if $set[removed] and doc[removed]?
      return false

    if $unset[removed] and not doc[removed]?
      return false

    if $set[removed] and not doc[removed]?
      $set[removed] = true

      if removedAt
        $set[removedAt] = new Date

      if removedBy
        $set[removedBy] = userId

      if restoredAt
        $unset[restoredAt] = true

      if restoredBy
        $unset[restoredBy] = true

    if $unset[removed] and doc[removed]?
      $unset[removed] = true

      if removedAt
        $unset[removedAt] = true

      if removedBy
        $unset[removedBy] = true

      if restoredAt
        $set[restoredAt] = new Date

      if restoredBy
        $set[restoredBy] = userId

    if _.isEmpty $set
      delete modifier.$set

    if _.isEmpty $unset
      delete modifier.$unset

  isLocalCollection = @collection._connection is null

  throwIfSelectorIsntId = (selector, method) ->
    unless _.isString(selector) or '_id' of selector
      throw new Meteor.Error 403, 'Not permitted. Untrusted code may only ' +
        "#{method} documents by ID."

  @collection.softRemove = (selector, callback) ->
    return 0 unless selector

    if Meteor.isClient and not isLocalCollection
      throwIfSelectorIsntId selector, 'softRemove'

    modifier =
      $set: $set = {}

    $set[removed] = true

    if Meteor.isServer or isLocalCollection
      ret = @update selector, modifier, multi: true, callback

    else
      ret = @update selector, modifier, callback

    if ret is false
      0
    else
      ret

  @collection.restore = (selector, callback) ->
    return 0 unless selector

    if Meteor.isClient and not isLocalCollection
      throwIfSelectorIsntId selector, 'restore'

    modifier =
      $unset: $unset = {}

    $unset[removed] = true

    if Meteor.isServer or isLocalCollection
      selector[removed] = true
      ret = @update selector, modifier, multi: true, callback

    else
      ret = @update selector, modifier, callback

    if ret is false
      0
    else
      ret

CollectionBehaviours.define 'softRemovable', behaviour
