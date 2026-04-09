import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const CardGameApp());
}

class CardGameApp extends StatelessWidget {
  const CardGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Category Solitaire',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

enum CardKind { category, item, wild }

enum Category {
  fruits,
  animals,
  colors,
  jobs,
  sports,
  food,
  countries,
  tools,
  music,
  nature,
}

String categoryLabel(Category c) {
  switch (c) {
    case Category.fruits:
      return '과일';
    case Category.animals:
      return '동물';
    case Category.colors:
      return '색깔';
    case Category.jobs:
      return '직업';
    case Category.sports:
      return '스포츠';
    case Category.food:
      return '음식';
    case Category.countries:
      return '나라';
    case Category.tools:
      return '도구';
    case Category.music:
      return '음악';
    case Category.nature:
      return '자연';
  }
}

/// 카테고리별 아이템 이름 풀 (한 슬롯에 3~8개만 사용).
List<String> categoryItemPool(Category c) {
  switch (c) {
    case Category.fruits:
      return ['사과', '포도', '바나나', '오렌지', '수박', '딸기', '키위', '망고'];
    case Category.animals:
      return ['강아지', '고양이', '토끼', '펭귄', '코끼리', '기린', '판다', '여우'];
    case Category.colors:
      return ['빨강', '파랑', '초록', '노랑', '보라', '주황', '검정', '하양'];
    case Category.jobs:
      return ['의사', '요리사', '경찰', '교사', '개발자', '디자이너', '운동선수', '가수'];
    case Category.sports:
      return ['축구', '야구', '농구', '배구', '테니스', '수영', '달리기', '스키'];
    case Category.food:
      return ['김치찌개', '피자', '초밥', '파스타', '햄버거', '샐러드', '라면', '떡볶이'];
    case Category.countries:
      return ['한국', '일본', '미국', '프랑스', '이탈리아', '스페인', '캐나다', '호주'];
    case Category.tools:
      return ['망치', '드라이버', '렌치', '톱', '줄자', '전동드릴', '펜치', '스패너'];
    case Category.music:
      return ['피아노', '기타', '바이올린', '드럼', '플룻', '색소폰', '첼로', '하프'];
    case Category.nature:
      return ['산', '바다', '숲', '강', '사막', '호수', '폭포', '초원'];
  }
}

@immutable
class GameCard {
  const GameCard({
    required this.id,
    required this.kind,
    required this.title,
    this.category,
    this.categoryTotalCount,
  });

  final String id;
  final CardKind kind;
  final String title;
  final Category? category;
  /// 카테고리 카드에만 사용: 이번 판에서 해당 카테고리 아이템 카드 개수.
  final int? categoryTotalCount;
}

enum PileType { stock, waste, tableau, foundation, wildReserve }

@immutable
class CardLocation {
  const CardLocation._(this.pileType, {this.index});

  const CardLocation.stock() : this._(PileType.stock);
  const CardLocation.waste() : this._(PileType.waste);
  const CardLocation.tableau(int index) : this._(PileType.tableau, index: index);
  const CardLocation.foundation(int index)
      : this._(PileType.foundation, index: index);
  const CardLocation.wildReserve() : this._(PileType.wildReserve);

  final PileType pileType;
  final int? index;

  @override
  String toString() => 'CardLocation($pileType, index: $index)';
}

@immutable
class MoveRecord {
  const MoveRecord({
    required this.cards,
    required this.from,
    required this.to,
    required this.faceUpSnapshotBefore,
    required this.movesUsedBefore,
  });

  final List<GameCard> cards;
  final CardLocation from;
  final CardLocation to;
  final Set<String> faceUpSnapshotBefore;
  final int movesUsedBefore;
}

class FoundationSlot {
  GameCard? categoryCard;
  final List<GameCard> items = <GameCard>[];
  List<String> requiredItemTitles = <String>[];

  Category? get category => categoryCard?.category;

  bool get isComplete =>
      categoryCard != null &&
      requiredItemTitles.isNotEmpty &&
      items.length >= requiredItemTitles.length;

  void clearSlot() {
    categoryCard = null;
    items.clear();
    requiredItemTitles.clear();
  }
}

/// 하단 테이블로(더미) 개수: 레벨마다 결정 (최소 3, 최대 6).
const int kTableauMin = 3;
const int kTableauMax = 6;

/// 상단 파운데이션 슬롯 수 (완료 시 비워져 다른 카테고리 수용).
const int kFoundationSlots = 4;

/// 카테고리당 아이템 수: 최소 3, 최대 8.
const int kItemsPerCategoryMin = 3;
const int kItemsPerCategoryMax = 8;

/// 플레이 영역 카드 공통 크기 (카테고리 카드 기준).
const double kPlayCardWidth = 88;
const double kPlayCardHeight = 118;

/// 카테고리 카드만: 노란 테두리·노란 뱃지 (내용은 아이템과 동일 스타일).
const Color kCategoryCardBorder = Color(0xFFF9A825);
const Color kCategoryCardBadgeFill = Color(0xFFFFEB3B);
const Color kCategoryCardBadgeBorder = Color(0xFFF9A825);

/// 테이블로: 위쪽 뒷면 스택 간격(겹침).
const double kTableauStackOffset = 28;

/// 맨 위 카드부터 **앞면**이면서 같은 카테고리가 이어지는 구간 (드래그 가능 묶음).
List<GameCard> tableauRunFromTop(List<GameCard> pile, Set<String> faceUp) {
  if (pile.isEmpty) return [];
  if (!faceUp.contains(pile.last.id)) return [];
  final top = pile.last;
  final cat = top.category;
  if (cat == null) return <GameCard>[top];
  var start = pile.length - 1;
  while (start > 0) {
    final prev = pile[start - 1];
    if (!faceUp.contains(prev.id)) break;
    if (prev.category != cat) break;
    start--;
  }
  return pile.sublist(start);
}

class GameState extends ChangeNotifier {
  /// 현재 레벨 (보드 클리어 시 증가).
  int _level = 1;
  int get level => _level;

  /// 이번 레벨의 하단 더미(열) 개수. 레벨이 오를 때만 바뀜 (새로고침으로는 안 바뀜).
  int _tableauColumnCount = kTableauMin;
  int get tableauColumnCount => _tableauColumnCount;

  final List<GameCard> stock = <GameCard>[];
  final List<GameCard> waste = <GameCard>[];
  List<List<GameCard>> tableaus = <List<GameCard>>[];
  final List<GameCard> wildReserve = <GameCard>[]; // 만능카드(버튼) 보관: 0~1장
  final List<FoundationSlot> foundations =
      List<FoundationSlot>.generate(kFoundationSlots, (_) => FoundationSlot());

  /// 시드 시점에 정해진 카테고리별 필요 아이템 목록 (슬롯에 카테고리 올릴 때 복사).
  final Map<Category, List<String>> _categoryRequirements = <Category, List<String>>{};

  final List<MoveRecord> _history = <MoveRecord>[];

  final Random _rnd = Random();

  /// 한 번이라도 앞면이 된 카드 id (다시 뒷면으로 돌아가지 않음).
  final Set<String> _faceUpCardIds = <String>{};
  bool _wildUsedThisLevel = false;
  int _movesUsed = 0;
  int _moveLimit = 0;

  bool get canUseWildCard => !_wildUsedThisLevel && wildReserve.isEmpty;
  int get movesUsed => _movesUsed;
  int get moveLimit => _moveLimit;
  int get movesRemaining => max(0, _moveLimit - _movesUsed);
  bool get hasMovesRemaining => movesRemaining > 0;

  bool isCardFaceUp(GameCard card) => _faceUpCardIds.contains(card.id);

  UnmodifiableSetView<String> get faceUpCardIds =>
      UnmodifiableSetView<String>(_faceUpCardIds);

  bool get canUndo => _history.isNotEmpty;

  GameState() {
    _level = 1;
    _tableauColumnCount = _tableauCountForLevel(_level);
    _dealCards();
  }

  /// 레벨마다 다른 시드로 열 개수 결정 (같은 레벨이면 항상 같은 개수).
  int _tableauCountForLevel(int level) {
    final r = Random(level * 11003 + 7919);
    return kTableauMin + r.nextInt(kTableauMax - kTableauMin + 1);
  }

  bool _isBoardClear() {
    if (stock.isNotEmpty || waste.isNotEmpty) return false;
    for (final t in tableaus) {
      if (t.isNotEmpty) return false;
    }
    for (final f in foundations) {
      if (f.categoryCard != null || f.items.isNotEmpty) return false;
    }
    return true;
  }

  void _tryAdvanceLevelIfBoardClear() {
    if (!_isBoardClear()) return;
    _level++;
    _tableauColumnCount = _tableauCountForLevel(_level);
    _dealCards();
  }

  List<String> _pickRequiredItemsForCategory(Category cat) {
    final pool = List<String>.of(categoryItemPool(cat))..shuffle(_rnd);
    final n = kItemsPerCategoryMin +
        _rnd.nextInt(kItemsPerCategoryMax - kItemsPerCategoryMin + 1);
    return pool.take(n).toList();
  }

  /// 같은 레벨·같은 열 개수로 카드만 다시 섞어 나눔 (새로고침).
  void _dealCards() {
    _categoryRequirements
      ..clear()
      ..addEntries(
        Category.values.map((c) => MapEntry(c, _pickRequiredItemsForCategory(c))),
      );

    final cards = <GameCard>[];
    for (final cat in Category.values) {
      final req = _categoryRequirements[cat]!;
      cards.add(
        GameCard(
          id: 'cat-${cat.name}',
          kind: CardKind.category,
          title: '카테고리: ${categoryLabel(cat)}',
          category: cat,
          categoryTotalCount: req.length,
        ),
      );
      for (final title in req) {
        final safe = title.replaceAll(RegExp(r'\s+'), '');
        cards.add(
          GameCard(
            id: 'item-${cat.name}-$safe',
            kind: CardKind.item,
            title: title,
            category: cat,
          ),
        );
      }
    }

    final shuffled = List<GameCard>.of(cards)..shuffle(_rnd);

    tableaus = List<List<GameCard>>.generate(_tableauColumnCount, (_) => <GameCard>[]);

    stock
      ..clear()
      ..addAll(shuffled);

    for (var i = 0; i < tableaus.length; i++) {
      tableaus[i].clear();
      // 테이블 카드 수를 조금 더 많게
      final count = 4 + (i % 3);
      for (var j = 0; j < count; j++) {
        if (stock.isEmpty) break;
        tableaus[i].add(stock.removeLast());
      }
    }

    waste.clear();
    wildReserve.clear();
    _wildUsedThisLevel = false;
    _movesUsed = 0;
    for (final f in foundations) {
      f.clearSlot();
    }

    _faceUpCardIds.clear();
    for (final pile in tableaus) {
      if (pile.isNotEmpty) {
        // 리스트: [0]=먼저 깔린 카드(화면 위) … [last]=나중에 깔린 카드(화면 아래 ‘맨 밑’).
        // 시작 시 맨 아래 한 장만 앞면 → pile.last
        _faceUpCardIds.add(pile.last.id);
      }
    }

    _history.clear();
    // 이동 제한: 아이템 총 개수 × 3
    final itemsTotal = _categoryRequirements.values.fold<int>(0, (a, b) => a + b.length);
    _moveLimit = itemsTotal * 3;
    notifyListeners();
  }

  /// 테이블로에서 카드를 빼면 새로 맨 아래(리스트 끝)로 드러난 카드 한 장만 앞면.
  void _flipNewTopAfterTableauRemoval(int columnIndex) {
    final pile = tableaus[columnIndex];
    if (pile.isEmpty) return;
    final card = pile.last;
    // '성공적으로 카드가 빠졌을 때'만 호출되는 함수.
    // 이미 앞면인 경우는 그대로 두고, 뒷면이면 1장만 깐다.
    if (_faceUpCardIds.contains(card.id)) return;
    _faceUpCardIds.add(card.id);
  }

  /// 현재 레벨 유지, 열 개수 유지, 카드만 다시 섞기.
  void reshuffleCurrentLevel() => _dealCards();

  /// 새로고침(같은 레벨·같은 열 개수로 다시 섞기).
  void reset() => reshuffleCurrentLevel();

  void drawFromStock() {
    if (!hasMovesRemaining) return;
    if (stock.isNotEmpty) {
      final snap = Set<String>.from(_faceUpCardIds);
      final card = stock.removeLast();
      waste.add(card);
      _faceUpCardIds.add(card.id);
      final movesBefore = _movesUsed;
      _movesUsed++;
      _history.add(
        MoveRecord(
          cards: <GameCard>[card],
          from: const CardLocation.stock(),
          to: const CardLocation.waste(),
          faceUpSnapshotBefore: snap,
          movesUsedBefore: movesBefore,
        ),
      );
      notifyListeners();
      _tryAdvanceLevelIfBoardClear();
      return;
    }

    // 솔리테어처럼: stock이 비면 waste를 다시 stock으로 되돌려서 뒤집기
    if (waste.isNotEmpty) {
      while (waste.isNotEmpty) {
        stock.add(waste.removeLast());
      }
      _history.clear(); // 리사이클은 단순화: undo 기록 초기화
      notifyListeners();
      _tryAdvanceLevelIfBoardClear();
    }
  }

  GameCard? topWaste() => waste.isEmpty ? null : waste.last;
  GameCard? topTableau(int i) => tableaus[i].isEmpty ? null : tableaus[i].last;

  bool canDropOnFoundation(int slotIndex, GameCard card) {
    final slot = foundations[slotIndex];
    if (slot.categoryCard == null) {
      return card.kind == CardKind.category;
    }

    if (card.kind == CardKind.wild) return false;
    if (card.kind != CardKind.item) return false;
    if (card.category != slot.category) return false;
    if (slot.requiredItemTitles.contains(card.title) == false) return false;
    if (slot.items.any((c) => c.title == card.title)) return false; // 중복 방지
    return true;
  }

  bool canMoveCategoryBundleToEmptyFoundation(int slotIndex, List<GameCard> cards) {
    if (cards.isEmpty) return false;
    final slot = foundations[slotIndex];
    if (slot.categoryCard != null) return false;
    final catCards = cards.where((c) => c.kind == CardKind.category).toList();
    if (catCards.length != 1) return false;
    final catCard = catCards.single;
    if (cards.any((c) => c.kind == CardKind.wild)) return false;
    if (cards.where((c) => c.kind == CardKind.item).length != cards.length - 1) return false;
    final cat = catCard.category;
    if (cat == null) return false;
    final required = _categoryRequirements[cat] ?? const <String>[];
    final seen = <String>{};
    for (final item in cards.where((c) => c.kind == CardKind.item)) {
      if (item.category != cat) return false;
      if (!required.contains(item.title)) return false;
      if (!seen.add(item.title)) return false;
    }
    return true;
  }

  bool moveCategoryBundleToEmptyFoundation({
    required List<GameCard> cards,
    required CardLocation from,
    required int foundationIndex,
  }) {
    if (!hasMovesRemaining) return false;
    if (!canMoveCategoryBundleToEmptyFoundation(foundationIndex, cards)) return false;
    final snap = Set<String>.from(_faceUpCardIds);
    final movesBefore = _movesUsed;
    if (!_removeCardsFromLocation(cards, from)) return false;
    if (from.pileType == PileType.tableau) {
      _flipNewTopAfterTableauRemoval(from.index!);
    }

    final slot = foundations[foundationIndex];
    final catCard = cards.singleWhere((c) => c.kind == CardKind.category);
    slot.categoryCard = catCard;
    slot.requiredItemTitles = List<String>.from(
      _categoryRequirements[catCard.category!] ?? const <String>[],
    );
    slot.items.addAll(cards.where((c) => c.kind == CardKind.item));
    if (slot.isComplete) {
      slot.clearSlot();
    }

    for (final c in cards) {
      _faceUpCardIds.add(c.id);
    }
    _movesUsed++; // 묶음 드래그 1회로 카운트
    _history.add(
      MoveRecord(
        cards: List<GameCard>.from(cards),
        from: from,
        to: CardLocation.foundation(foundationIndex),
        faceUpSnapshotBefore: snap,
        movesUsedBefore: movesBefore,
      ),
    );
    notifyListeners();
    _tryAdvanceLevelIfBoardClear();
    return true;
  }

  bool canDropOnTableau(int tableauIndex, GameCard card) {
    // 규칙: 같은 카테고리끼리만 쌓을 수 있음.
    // - 빈 더미: 아무 카드나 가능 (카테고리 카드가 섞여 있으니 탐색/정리용)
    // - 카드가 있는 더미: 맨 위가 앞면이어야 하고, 맨 위와 category가 같아야 함
    final pile = tableaus[tableauIndex];
    if (pile.isEmpty) return true;

    final top = pile.last;
    if (!_faceUpCardIds.contains(top.id)) return false;
    // 만능카드는 어디든 놓을 수 있고, 만능카드 위에는 무엇이든 놓을 수 있음.
    if (card.kind == CardKind.wild) return true;
    if (top.kind == CardKind.wild) return true;
    // 규칙: 테이블에서 카테고리 카드 위에는 아이템 카드가 못 올라감.
    if (top.kind == CardKind.category && card.kind == CardKind.item) return false;
    final topCat = top.category;
    final cardCat = card.category;

    if (topCat == null || cardCat == null) return false;
    return topCat == cardCat;
  }

  bool moveCardToFoundation({
    required GameCard card,
    required CardLocation from,
    required int foundationIndex,
  }) {
    if (!hasMovesRemaining) return false;
    if (!canDropOnFoundation(foundationIndex, card)) return false;

    final snap = Set<String>.from(_faceUpCardIds);
    final movesBefore = _movesUsed;
    if (!_removeCardsFromLocation(<GameCard>[card], from)) return false;

    if (from.pileType == PileType.tableau) {
      _flipNewTopAfterTableauRemoval(from.index!);
    }

    final slot = foundations[foundationIndex];
    if (slot.categoryCard == null) {
      slot.categoryCard = card;
      slot.requiredItemTitles = List<String>.from(
        _categoryRequirements[card.category!] ?? const <String>[],
      );
    } else {
      slot.items.add(card);
      if (slot.isComplete) {
        slot.clearSlot();
      }
    }

    _faceUpCardIds.add(card.id);
    _movesUsed++;
    _history.add(
      MoveRecord(
        cards: <GameCard>[card],
        from: from,
        to: CardLocation.foundation(foundationIndex),
        faceUpSnapshotBefore: snap,
        movesUsedBefore: movesBefore,
      ),
    );
    notifyListeners();
    _tryAdvanceLevelIfBoardClear();
    return true;
  }

  bool moveCardsToTableau({
    required List<GameCard> cards,
    required CardLocation from,
    required int tableauIndex,
  }) {
    if (!hasMovesRemaining) return false;
    if (cards.isEmpty) return false;
    // 같은 열로 다시 놓는 건 "취소"로 보고 아무 변화도 없게.
    if (from.pileType == PileType.tableau && from.index == tableauIndex) return false;
    if (!canDropOnTableau(tableauIndex, cards.first)) return false;
    final snap = Set<String>.from(_faceUpCardIds);
    final movesBefore = _movesUsed;
    if (!_removeCardsFromLocation(cards, from)) return false;

    if (from.pileType == PileType.tableau) {
      _flipNewTopAfterTableauRemoval(from.index!);
    }

    tableaus[tableauIndex].addAll(cards);
    for (final c in cards) {
      _faceUpCardIds.add(c.id);
    }
    _movesUsed++;
    _history.add(
      MoveRecord(
        cards: List<GameCard>.from(cards),
        from: from,
        to: CardLocation.tableau(tableauIndex),
        faceUpSnapshotBefore: snap,
        movesUsedBefore: movesBefore,
      ),
    );
    notifyListeners();
    _tryAdvanceLevelIfBoardClear();
    return true;
  }

  void undo() {
    if (_history.isEmpty) return;
    final last = _history.removeLast();

    _faceUpCardIds
      ..clear()
      ..addAll(last.faceUpSnapshotBefore);
    _movesUsed = last.movesUsedBefore;

    _removeCardsFromLocation(last.cards, last.to);
    _addCardsToLocation(last.cards, last.from);

    notifyListeners();
    _tryAdvanceLevelIfBoardClear();
  }

  bool _removeCardsFromLocation(List<GameCard> cards, CardLocation loc) {
    if (cards.isEmpty) return true;
    switch (loc.pileType) {
      case PileType.stock:
        if (cards.length != 1) return false;
        return stock.remove(cards.single);
      case PileType.waste:
        if (cards.length != 1) return false;
        return waste.remove(cards.single);
      case PileType.tableau:
        final i = loc.index!;
        final pile = tableaus[i];
        if (pile.length < cards.length) return false;
        final tail = pile.sublist(pile.length - cards.length);
        for (var j = 0; j < cards.length; j++) {
          if (tail[j].id != cards[j].id) return false;
        }
        pile.removeRange(pile.length - cards.length, pile.length);
        return true;
      case PileType.foundation:
        if (cards.length != 1) return false;
        final card = cards.single;
        final slot = foundations[loc.index!];
        if (slot.categoryCard?.id == card.id) {
          slot.clearSlot();
          return true;
        }
        return slot.items.remove(card);
      case PileType.wildReserve:
        if (cards.length != 1) return false;
        return wildReserve.remove(cards.single);
    }
  }

  void _addCardsToLocation(List<GameCard> cards, CardLocation loc) {
    if (cards.isEmpty) return;
    switch (loc.pileType) {
      case PileType.stock:
        for (final c in cards) {
          stock.add(c);
        }
        return;
      case PileType.waste:
        for (final c in cards) {
          waste.add(c);
        }
        return;
      case PileType.tableau:
        tableaus[loc.index!].addAll(cards);
        return;
      case PileType.foundation:
        final slot = foundations[loc.index!];
        for (final card in cards) {
          if (card.kind == CardKind.category) {
            slot.categoryCard = card;
            slot.requiredItemTitles = List<String>.from(
              _categoryRequirements[card.category!] ?? const <String>[],
            );
          } else {
            slot.items.add(card);
          }
        }
        return;
      case PileType.wildReserve:
        wildReserve.addAll(cards);
        return;
    }
  }

  void spawnWildCardOncePerLevel() {
    if (!hasMovesRemaining) return;
    if (!canUseWildCard) return;
    final card = GameCard(
      id: 'wild-$level-${DateTime.now().microsecondsSinceEpoch}',
      kind: CardKind.wild,
      title: '만능카드',
      category: null,
    );
    wildReserve.add(card);
    _faceUpCardIds.add(card.id);
    _wildUsedThisLevel = true;
    _movesUsed++;
    notifyListeners();
  }
}

@immutable
class DragPayload {
  const DragPayload({required this.cards, required this.from});

  /// 이동하는 카드들. 테이블로에서는 맨 위부터 같은 카테고리로 이어진 묶음.
  final List<GameCard> cards;
  final CardLocation from;
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameState _game = GameState();

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _game,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF143D2E),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF143D2E),
                  Color(0xFF1B5E3A),
                  Color(0xFF0F3D26),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1) 상단 오른쪽: 오픈 + 덱 (한 장씩 넘기기)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 180,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                tooltip: '메뉴',
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('새로 하시겠습니까?'),
                                        content: const Text('현재 판이 초기화됩니다.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: const Text('취소'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: const Text('새로하기'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (ok == true) {
                                    _game.reset();
                                  }
                                },
                                icon: Icon(Icons.menu, color: Colors.white.withValues(alpha: 0.85)),
                              ),
                              Container(
                                width: 160,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.black.withValues(alpha: 0.22),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '이동',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.70),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${_game.movesRemaining}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _WastePile(
                                  card: _game.topWaste(),
                                  from: const CardLocation.waste(),
                                ),
                                const SizedBox(width: 8),
                                _StockPile(
                                  count: _game.stock.length,
                                  onTap: _game.hasMovesRemaining ? _game.drawFromStock : () {},
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 2) 그 아래: 파운데이션 슬롯
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _FoundationsRow(game: _game),
                    ),
                  ),
                  // 3) 그 아래: 하단 테이블로
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List<Widget>.generate(_game.tableaus.length, (i) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _TableauPile(
                                cards: _game.tableaus[i],
                                pileIndex: i,
                                game: _game,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      border: Border(
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: Row(
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.16),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _game.canUndo ? _game.undo : null,
                          icon: const Icon(Icons.undo),
                          label: const Text('되돌리기'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _game.canUseWildCard
                                ? const Color(0xFFD4AF37).withValues(alpha: 0.28)
                                : Colors.white.withValues(alpha: 0.10),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: (_game.canUseWildCard && _game.hasMovesRemaining)
                              ? _game.spawnWildCardOncePerLevel
                              : null,
                          icon: const Icon(Icons.workspace_premium),
                          label: const Text('만능카드'),
                        ),
                        const SizedBox(width: 10),
                        _WildReserveWidget(game: _game),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StockPile extends StatelessWidget {
  const _StockPile({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: kPlayCardWidth,
          height: kPlayCardHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E4A7A),
                        Color(0xFF2E6CAD),
                        Color(0xFF183A5C),
                      ],
                    ),
                  ),
                  child: count == 0
                      ? Center(
                          child: Text(
                            '리셋',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : CustomPaint(
                          painter: _CardBackDotsPainter(),
                        ),
                ),
              ),
              if (count > 0)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A365D),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 덱 뒷면 텍스처 (가벼운 도트)
class _CardBackDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.1);
    const step = 10.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x + 2, y + 2), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WastePile extends StatelessWidget {
  const _WastePile({required this.card, required this.from});
  final GameCard? card;
  final CardLocation from;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kPlayCardWidth,
      height: kPlayCardHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: card == null
            ? Center(
                child: Text(
                  '오픈',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _DraggableCard(
                  cards: <GameCard>[card!],
                  from: from,
                  playCardSize: true,
                ),
              ),
      ),
    );
  }
}

class _WildReserveWidget extends StatelessWidget {
  const _WildReserveWidget({required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    if (game.wildReserve.isEmpty) {
      return SizedBox(
        width: kPlayCardWidth,
        height: kPlayCardHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            color: Colors.white.withValues(alpha: 0.06),
          ),
          child: Center(
            child: Text(
              '만능',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    final card = game.wildReserve.single;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: _DraggableCard(
        cards: <GameCard>[card],
        from: const CardLocation.wildReserve(),
        playCardSize: true,
      ),
    );
  }
}

class _FoundationsRow extends StatelessWidget {
  const _FoundationsRow({required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(game.foundations.length, (i) {
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
          child: _FoundationSlotWidget(game: game, slotIndex: i),
        );
      }),
    );
  }
}

class _FoundationSlotWidget extends StatelessWidget {
  const _FoundationSlotWidget({required this.game, required this.slotIndex});
  final GameState game;
  final int slotIndex;

  @override
  Widget build(BuildContext context) {
    final slot = game.foundations[slotIndex];

    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (details) {
        final payload = details.data;
        if (payload.cards.isEmpty) return false;
        // 부분 성공 금지.
        // - 슬롯이 비어있고, (카테고리 + 아이템들) 묶음이면 "통째로" 올라갈 수 있을 때만 허용
        // - 그 외에는 기존처럼 payload 전부가 허용될 때만 허용
        if (slot.categoryCard == null &&
            payload.cards.any((c) => c.kind == CardKind.category)) {
          return game.canMoveCategoryBundleToEmptyFoundation(slotIndex, payload.cards);
        }

        for (final card in payload.cards.reversed) {
          if (!game.canDropOnFoundation(slotIndex, card)) return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        final payload = details.data;
        // 부분 성공 금지: 하나라도 안 되면 아무것도 이동하지 않음.
        if (slot.categoryCard == null &&
            payload.cards.isNotEmpty &&
            payload.cards.any((c) => c.kind == CardKind.category)) {
          game.moveCategoryBundleToEmptyFoundation(
            cards: payload.cards,
            from: payload.from,
            foundationIndex: slotIndex,
          );
          return;
        }

        for (final card in payload.cards.reversed) {
          if (!game.canDropOnFoundation(slotIndex, card)) return;
        }
        for (final card in payload.cards.reversed) {
          final ok = game.moveCardToFoundation(
            card: card,
            from: payload.from,
            foundationIndex: slotIndex,
          );
          if (!ok) return;
        }
      },
      builder: (context, candidate, rejected) {
        final isActive = candidate.isNotEmpty;

        return SizedBox(
          width: kPlayCardWidth,
          height: kPlayCardHeight,
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFFFD54F)
                      : Colors.white.withValues(alpha: 0.22),
                  width: isActive ? 2 : 1,
                ),
                color: const Color(0xFF0D3D24),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (slot.categoryCard == null)
                    Center(
                      child: Text(
                        '슬롯',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.18),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else ...[
                    Positioned.fill(
                      child: _CardFace(
                        card: slot.categoryCard!,
                        playCardSize: true,
                      ),
                    ),
                    for (final item in slot.items)
                      Positioned.fill(
                        child: _CardFace(
                          card: item,
                          playCardSize: true,
                        ),
                      ),
                  ],
                  if (slot.categoryCard != null && slot.items.isNotEmpty)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${slot.items.length}/${slot.requiredItemTitles.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 테이블로: 아래쪽 고정 카드 + 맨 위 같은 카테고리 묶음만 Draggable.
List<Widget> _tableauPileStackWidgets({
  required List<GameCard> cards,
  required int pileIndex,
  required GameState game,
}) {
  final run = tableauRunFromTop(cards, game.faceUpCardIds);
  final runStart = cards.length - run.length;
  final out = <Widget>[];

  for (var i = 0; i < runStart; i++) {
    out.add(
      Positioned(
        left: 0,
        right: 0,
        top: 8.0 + (i * kTableauStackOffset),
        child: Align(
          alignment: Alignment.topCenter,
          child: _CardFace(
            card: cards[i],
            playCardSize: true,
            faceDown: !game.isCardFaceUp(cards[i]),
            stackTextLift: i < cards.length - 1,
          ),
        ),
      ),
    );
  }

  if (run.isNotEmpty) {
    out.add(
      Positioned(
        left: 0,
        right: 0,
        top: 8.0 + (runStart * kTableauStackOffset),
        child: Align(
          alignment: Alignment.topCenter,
          child: _DraggableCard(
            cards: run,
            from: CardLocation.tableau(pileIndex),
            playCardSize: true,
          ),
        ),
      ),
    );
  }

  return out;
}

class _TableauPile extends StatelessWidget {
  const _TableauPile({
    required this.cards,
    required this.pileIndex,
    required this.game,
  });

  final List<GameCard> cards;
  final int pileIndex;
  final GameState game;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (details) =>
          game.canDropOnTableau(pileIndex, details.data.cards.first),
      onAcceptWithDetails: (details) {
        game.moveCardsToTableau(
          cards: details.data.cards,
          from: details.data.from,
          tableauIndex: pileIndex,
        );
      },
      builder: (context, candidate, rejected) {
        final isActive = candidate.isNotEmpty;
        return Container(
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFFFD54F)
                  : Colors.white.withValues(alpha: 0.14),
            ),
            color: Colors.black.withValues(alpha: 0.12),
          ),
          child: Stack(
            children: [
              if (cards.isEmpty)
                Center(
                  child: Text(
                    '테이블로',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ..._tableauPileStackWidgets(
                  cards: cards,
                  pileIndex: pileIndex,
                  game: game,
                ),
              // 테이블 카드 장수 표시는 숨김
            ],
          ),
        );
      },
    );
  }
}

/// 테이블로/오픈: `cards`가 1장이면 한 장만, 여러 장이면 겹쳐 보이게.
class _TableauRunStack extends StatelessWidget {
  const _TableauRunStack({required this.cards, required this.playCardSize});
  final List<GameCard> cards;
  final bool playCardSize;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    if (cards.length == 1) {
      return _CardFace(
        card: cards.single,
        playCardSize: playCardSize,
        stackTextLift: false,
      );
    }
    final h = (cards.length - 1) * kTableauStackOffset + kPlayCardHeight;
    return SizedBox(
      width: kPlayCardWidth,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var j = 0; j < cards.length; j++)
            Positioned(
              top: j * kTableauStackOffset,
              left: 0,
              right: 0,
              child: _CardFace(
                card: cards[j],
                playCardSize: playCardSize,
                stackTextLift: j < cards.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _DraggableCard extends StatelessWidget {
  const _DraggableCard({
    required this.cards,
    required this.from,
    this.playCardSize = false,
  });
  final List<GameCard> cards;
  final CardLocation from;
  final bool playCardSize;

  @override
  Widget build(BuildContext context) {
    return Draggable<DragPayload>(
      data: DragPayload(cards: List<GameCard>.from(cards), from: from),
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.03,
          child: _TableauRunStack(cards: cards, playCardSize: playCardSize),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.15,
        child: _TableauRunStack(cards: cards, playCardSize: playCardSize),
      ),
      child: _TableauRunStack(cards: cards, playCardSize: playCardSize),
    );
  }
}

class _PlayCardBack extends StatelessWidget {
  const _PlayCardBack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kPlayCardWidth,
      height: kPlayCardHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E4A7A),
              Color(0xFF2E6CAD),
              Color(0xFF183A5C),
            ],
          ),
        ),
        child: CustomPaint(
          painter: _CardBackDotsPainter(),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    this.playCardSize = false,
    this.stackTextLift = false,
    this.faceDown = false,
  });

  final GameCard card;
  /// [kPlayCardWidth]×[kPlayCardHeight] 고정 (카테고리 카드와 동일 크기).
  final bool playCardSize;

  /// 테이블로에서 아래에 카드가 얹히는 경우 글자를 위로 올려 가려진 부분을 줄임.
  final bool stackTextLift;

  /// 아직 까지지 않은 카드 (테이블로 뒷면).
  final bool faceDown;

  @override
  Widget build(BuildContext context) {
    if (faceDown) {
      return const _PlayCardBack();
    }
    final Widget inner;
    if (playCardSize) {
      inner = SizedBox(
        width: kPlayCardWidth,
        height: kPlayCardHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _cardFaceBody(context, dense: true);
          },
        ),
      );
    } else {
      inner = LayoutBuilder(
        builder: (context, constraints) {
          final maxH =
              constraints.hasBoundedHeight ? constraints.maxHeight : double.infinity;
          final dense = maxH < 64;
          return _cardFaceBody(context, dense: dense);
        },
      );
    }

    return inner;
  }

  Widget _cardFaceBody(BuildContext context, {required bool dense}) {
    final cs = Theme.of(context).colorScheme;
    final isWild = card.kind == CardKind.wild;
    final isCategory = card.kind == CardKind.category;
    final padding = dense ? const EdgeInsets.all(8) : const EdgeInsets.all(12);

    final titleStyle = dense
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.titleMedium;

    final textStyle = titleStyle?.copyWith(
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
    );

    if (isWild) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFD54F), width: 2),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB8860B),
              Color(0xFFFFD54F),
              Color(0xFF8D6E00),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium, color: Colors.black.withValues(alpha: 0.75), size: dense ? 28 : 34),
              const SizedBox(height: 6),
              Text(
                '만능',
                style: (titleStyle ?? const TextStyle()).copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!isCategory) {
      final textChild = Text(
        card.title,
        textAlign: TextAlign.center,
        maxLines: dense ? 2 : 3,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
          color: cs.surface,
        ),
        child: Padding(
          padding: stackTextLift
              ? const EdgeInsets.fromLTRB(8, 10, 8, 8)
              : padding,
          child: stackTextLift
              ? Align(
                  alignment: Alignment.topCenter,
                  child: textChild,
                )
              : Center(child: textChild),
        ),
      );
    }

    final displayName =
        card.category != null ? categoryLabel(card.category!) : card.title;

    final nameText = Text(
      displayName,
      textAlign: TextAlign.center,
      maxLines: dense ? 2 : 3,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kCategoryCardBorder, width: 2),
            color: cs.surface,
          ),
          child: Padding(
            padding: stackTextLift
                ? const EdgeInsets.fromLTRB(8, 24, 8, 8)
                : padding,
            child: stackTextLift
                ? Align(
                    alignment: Alignment.topCenter,
                    child: nameText,
                  )
                : Center(child: nameText),
          ),
        ),
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            width: 28,
            height: 16,
            decoration: BoxDecoration(
              color: kCategoryCardBadgeFill,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kCategoryCardBadgeBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              card.kind == CardKind.category && card.categoryTotalCount != null
                  ? '${card.categoryTotalCount}'
                  : '',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: Colors.black.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

