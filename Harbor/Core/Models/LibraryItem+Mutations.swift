import Foundation

extension LibraryItem {
    mutating func updatePlaybackProgress(
        from target: StreamTarget,
        offset: Double,
        duration: Double,
        timestamp: String = HarborDate.timestamp()
    ) {
        applyMetadata(from: target)
        var state = self.state ?? LibraryState()
        let videoChanged = target.videoId != nil
            && state.videoId != nil
            && state.videoId != target.videoId
        if videoChanged {
            state.overallTimeWatched = (state.overallTimeWatched ?? 0) + (state.timeWatched ?? 0)
            state.flaggedWatched = 0
        }
        state.timeOffset = (state.flaggedWatched ?? 0) > 0 ? 0 : offset
        state.timeWatched = offset
        state.duration = videoChanged ? duration : max(duration, state.duration ?? 0)
        if let videoID = target.videoId {
            state.videoId = videoID
            if let coordinates = EpisodeCoordinates(videoID: videoID) {
                state.season = coordinates.season
                state.episode = coordinates.episode
            }
        }
        state.lastWatched = timestamp
        state.timesWatched = state.timesWatched ?? 0
        state.overallTimeWatched = state.overallTimeWatched ?? 0
        state.noNotif = state.noNotif ?? false
        self.state = state
        if removed {
            temp = true
        }
        removed = false
    }

    mutating func markPlaybackWatched(
        from target: StreamTarget,
        timestamp: String = HarborDate.timestamp()
    ) {
        applyMetadata(from: target)
        var state = self.state ?? LibraryState()
        state.flaggedWatched = 1
        state.timeOffset = 0
        if let videoID = target.videoId {
            state.videoId = videoID
        }
        state.timesWatched = (state.timesWatched ?? 0) + 1
        state.lastWatched = timestamp
        self.state = state
        if removed {
            temp = true
        }
        removed = false
    }

    mutating func setBookmarkRemoved(_ shouldRemove: Bool, metadata: Meta) {
        if name.isEmpty {
            name = metadata.name
            type = metadata.type
            poster = metadata.poster
            background = metadata.background
            posterShape = "poster"
        }
        removed = shouldRemove
        temp = false
    }

    mutating func removeFromContinueWatching() {
        var state = self.state ?? LibraryState()
        state.timeOffset = 0
        self.state = state
        removed = true
        temp = false
    }

    private mutating func applyMetadata(from target: StreamTarget) {
        type = target.type
        if name.isEmpty {
            name = target.metaName
        }
        if poster == nil {
            poster = target.poster
        }
        if background == nil {
            background = target.background
        }
    }
}
