part of 'favorites_page.dart';

class _LocalFavoritesPage extends StatefulWidget {
  const _LocalFavoritesPage({required this.folder, super.key});

  final String folder;

  @override
  State<_LocalFavoritesPage> createState() => _LocalFavoritesPageState();
}

class _LocalFavoritesPageState extends State<_LocalFavoritesPage> {
  late _FavoritesPageState favPage;

  late List<FavoriteItem> comics;

  void updateComics() {
    setState(() {
      comics = LocalFavoritesManager().getAllComics(widget.folder);
    });
  }

  @override
  void initState() {
    favPage = context.findAncestorStateOfType<_FavoritesPageState>()!;
    comics = LocalFavoritesManager().getAllComics(widget.folder);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(
          leading: Tooltip(
            message: "Folders".tl,
            child: context.width <= _kTwoPanelChangeWidth
                ? IconButton(
                    icon: const Icon(Icons.menu),
                    color: context.colorScheme.primary,
                    onPressed: favPage.showFolderSelector,
                  )
                : const SizedBox(),
          ),
          title: Text(favPage.folder ?? "Unselected".tl),
          actions: [
            MenuButton(
              entries: [
                MenuEntry(
                    icon: Icons.delete_outline,
                    text: "Delete Folder".tl,
                    onClick: () {
                      showConfirmDialog(
                        context: App.rootContext,
                        title: "Delete".tl,
                        content:
                            "Are you sure you want to delete this folder?".tl,
                        onConfirm: () {
                          favPage.setFolder(false, null);
                          LocalFavoritesManager().deleteFolder(widget.folder);
                          favPage.folderList?.updateFolders();
                          context.pop();
                        },
                      );
                    }),
                MenuEntry(
                    icon: Icons.edit_outlined,
                    text: "Rename".tl,
                    onClick: () {
                      showInputDialog(
                        context: App.rootContext,
                        title: "Rename".tl,
                        hintText: "New Name".tl,
                        onConfirm: (value) {
                          var err = validateFolderName(value.toString());
                          if (err != null) {
                            return err;
                          }
                          LocalFavoritesManager().rename(
                            widget.folder,
                            value.toString(),
                          );
                          favPage.folderList?.updateFolders();
                          favPage.setFolder(false, value.toString());
                          return null;
                        },
                      );
                    }),
                MenuEntry(
                    icon: Icons.reorder,
                    text: "Reorder".tl,
                    onClick: () {
                      context.to(
                        () {
                          return _ReorderComicsPage(
                            widget.folder,
                            (comics) {
                              this.comics = comics;
                            },
                          );
                        },
                      ).then(
                        (value) {
                          setState(() {});
                        },
                      );
                    }),
              ],
            ),
          ],
        ),
        SliverGridComics(
          comics: comics.map((e) {
            var comicSource = e.type.comicSource;
            return Comic(
              e.name,
              e.coverPath,
              e.id,
              e.author,
              e.tags,
              "${e.time} | ${comicSource?.name ?? "Unknown"}",
              comicSource?.key ?? "Unknown",
              null,
            );
          }).toList(),
          menuBuilder: (c) {
            return [
              MenuEntry(
                icon: Icons.delete_outline,
                text: "Delete".tl,
                onClick: () {
                  showConfirmDialog(
                    context: context,
                    title: "Delete".tl,
                    content: "Are you sure you want to delete this comic?".tl,
                    onConfirm: () {
                      LocalFavoritesManager().deleteComicWithId(
                        widget.folder,
                        c.id,
                        ComicType(c.sourceKey.hashCode),
                      );
                      updateComics();
                    },
                  );
                },
              ),
            ];
          },
        ),
      ],
    );
  }
}

class _ReorderComicsPage extends StatefulWidget {
  const _ReorderComicsPage(this.name, this.onReorder);

  final String name;

  final void Function(List<FavoriteItem>) onReorder;

  @override
  State<_ReorderComicsPage> createState() => _ReorderComicsPageState();
}

class _ReorderComicsPageState extends State<_ReorderComicsPage> {
  final _key = GlobalKey();
  var reorderWidgetKey = UniqueKey();
  final _scrollController = ScrollController();
  late var comics = LocalFavoritesManager().getAllComics(widget.name);
  bool changed = false;

  Color lightenColor(Color color, double lightenValue) {
    int red = (color.red + ((255 - color.red) * lightenValue)).round();
    int green = (color.green + ((255 - color.green) * lightenValue)).round();
    int blue = (color.blue + ((255 - color.blue) * lightenValue)).round();

    return Color.fromARGB(color.alpha, red, green, blue);
  }

  @override
  void dispose() {
    if (changed) {
      LocalFavoritesManager().reorder(comics, widget.name);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var tiles = comics.map(
      (e) {
        var comicSource = e.type.comicSource;
        return ComicTile(
          key: Key(e.hashCode.toString()),
          comic: Comic(
            e.name,
            e.coverPath,
            e.id,
            e.author,
            e.tags,
            "${e.time} | ${comicSource?.name ?? "Unknown"}",
            comicSource?.key ?? "Unknown",
            null,
          ),
        );
      },
    ).toList();
    return Scaffold(
      appBar: Appbar(
        title: Text("Reorder".tl),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showInfoDialog(
                context: context,
                title: "Reorder".tl,
                content: "Long press and drag to reorder.".tl,
              );
            },
          ),
        ],
      ),
      body: ReorderableBuilder(
        key: reorderWidgetKey,
        scrollController: _scrollController,
        longPressDelay: App.isDesktop
            ? const Duration(milliseconds: 100)
            : const Duration(milliseconds: 500),
        onReorder: (reorderFunc) {
          changed = true;
          setState(() {
            comics = reorderFunc(comics) as List<FavoriteItem>;
          });
          widget.onReorder(comics);
        },
        dragChildBoxDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: lightenColor(
            Theme.of(context).splashColor.withOpacity(1),
            0.2,
          ),
        ),
        builder: (children) {
          return GridView(
            key: _key,
            controller: _scrollController,
            gridDelegate: SliverGridDelegateWithComics(),
            children: children,
          );
        },
        children: tiles,
      ),
    );
  }
}