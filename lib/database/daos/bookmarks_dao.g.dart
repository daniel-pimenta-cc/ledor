// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmarks_dao.dart';

// ignore_for_file: type=lint
mixin _$BookmarksDaoMixin on DatabaseAccessor<AppDatabase> {
  $BookmarksTableTable get bookmarksTable => attachedDatabase.bookmarksTable;
  BookmarksDaoManager get managers => BookmarksDaoManager(this);
}

class BookmarksDaoManager {
  final _$BookmarksDaoMixin _db;
  BookmarksDaoManager(this._db);
  $$BookmarksTableTableTableManager get bookmarksTable =>
      $$BookmarksTableTableTableManager(
        _db.attachedDatabase,
        _db.bookmarksTable,
      );
}
