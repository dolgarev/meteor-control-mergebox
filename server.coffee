guardObject = {}

originalPublish = Meteor.publish
Meteor.publish = (name, publishFunction) ->
  originalPublish name, (args...) ->
    publish = @

    originalAdded = publish.added
    publish.added = (collectionName, id, fields) ->
      stringId = @_idFilter.idStringify id

      FiberUtils.synchronize guardObject, "#{collectionName}#{stringId}", =>
        collectionView = @_session.getCollectionView collectionName

        originalSessionDocumentView = collectionView.documents[stringId]

        # Make sure we start with a clean slate for this document ID.
        delete collectionView.documents[stringId]

        try
          originalAdded.call @, collectionName, id, fields
        finally
          if originalSessionDocumentView
            collectionView.documents[stringId] = originalSessionDocumentView
          else
            delete collectionView.documents[stringId]

    originalChanged = publish.changed
    publish.changed = (collectionName, id, fields) ->
      stringId = @_idFilter.idStringify id

      FiberUtils.synchronize guardObject, "#{collectionName}#{stringId}", =>
        collectionView = @_session.getCollectionView collectionName

        originalSessionDocumentView = collectionView.documents[stringId]

        # Create an empty session document for this id.
        collectionView.documents[id] = new DDPServer._SessionDocumentView()

        # For fields which are being cleared we have to mock some existing
        # value otherwise change will not be send to the client.
        for field, value of fields when value is undefined
          collectionView.documents[id].dataByKey[field] = [subscriptionHandle: @_subscriptionHandle, value: null]

        try
          originalChanged.call @, collectionName, id, fields
        finally
          if originalSessionDocumentView
            collectionView.documents[stringId] = originalSessionDocumentView
          else
            delete collectionView.documents[stringId]

    originalRemoved = publish.removed
    publish.removed = (collectionName, id) ->
      stringId = @_idFilter.idStringify id

      FiberUtils.synchronize guardObject, "#{collectionName}#{stringId}", =>
        collectionView = @_session.getCollectionView collectionName

        originalSessionDocumentView = collectionView.documents[stringId]

        # Create an empty session document for this id.
        collectionView.documents[id] = new DDPServer._SessionDocumentView()

        try
          originalRemoved.call @, collectionName, id
        finally
          if originalSessionDocumentView
            collectionView.documents[stringId] = originalSessionDocumentView
          else
            delete collectionView.documents[stringId]

    publishFunction.apply publish, args
