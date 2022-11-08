import 'package:domain_models/domain_models.dart';
import 'package:fav_qs_api/fav_qs_api.dart';
import 'package:key_value_storage/key_value_storage.dart';
import 'package:meta/meta.dart';
import 'package:quote_repository/src/mappers/mappers.dart';
import 'package:quote_repository/src/quote_local_storage.dart';

class QuoteRepository {
  QuoteRepository({
    required KeyValueStorage keyValueStorage,
    required this.remoteApi,
    @visibleForTesting QuoteLocalStorage? localStorage,
  }) : _localStorage = localStorage ??
            QuoteLocalStorage(
              keyValueStorage: keyValueStorage,
            );

  final FavQsApi remoteApi;
  final QuoteLocalStorage _localStorage;

  Stream<QuoteListPage> getQuoteListPage(
    int pageNumber, {
    Tag? tag,
    String searchTerm = '',
    String? favoritedByUsername,
    required QuoteListPageFetchPolicy fetchPolicy,
  }) async* {
    final isFilteringByTag = tag != null;
    final isSearching = searchTerm.isNotEmpty;
    final isFetchPolicyNetworkOnly =
        fetchPolicy == QuoteListPageFetchPolicy.networkOnly;
    final shouldSkipCacheLookup =
        isFilteringByTag || isSearching || isFetchPolicyNetworkOnly;

    if (shouldSkipCacheLookup) {
      final freshPage = await _getQuoteListPageFromNetwork(
        pageNumber,
        tag: tag,
        searchTerm: searchTerm,
        favoritedByUsername: favoritedByUsername,
      );

      yield freshPage;
    } else {
      final isFilteringByFavorites = favoritedByUsername != null;

      final cachedPage = await _localStorage.getQuoteListPage(
        pageNumber,
        isFilteringByFavorites,
      );

      final isFetchPolicyCacheAndNetwork =
          fetchPolicy == QuoteListPageFetchPolicy.cacheAndNetwork;

      final isFetchPolicyCachePreferably =
          fetchPolicy == QuoteListPageFetchPolicy.cachePreferably;

      final shouldEmitCachedPageInAdvance =
          isFetchPolicyCachePreferably || isFetchPolicyCacheAndNetwork;

      if (shouldEmitCachedPageInAdvance && cachedPage != null) {
        yield cachedPage.toDomainModel();
        if (isFetchPolicyCachePreferably) {
          return;
        }
      }

      try {
        final freshPage = await _getQuoteListPageFromNetwork(
          pageNumber,
          favoritedByUsername: favoritedByUsername,
        );

        yield freshPage;
      } catch (_) {
        //정책이 networkPreferably있고 네트워크에서 페이지를 가져오는 중에 오류가 발생한 경우
        // 캐시된 페이지가 있는 경우 대신 캐시된 페이지를 내보내 오류를 되돌리려고 시도합니다.
        final isFetchPolicyNetworkPreferably =
            fetchPolicy == QuoteListPageFetchPolicy.networkPreferably;
        if (cachedPage != null && isFetchPolicyNetworkPreferably) {
          yield cachedPage.toDomainModel();
          return;
        }

        //정책이 cacheAndNetwork또는 cachePreferably이면 몇 줄 전에 이미 캐시된 페이지를 내보냈으므로 이제 rethrow
        // 네트워크 호출이 실패할 경우 오류가 발생하는 것만 선택할 수 있습니다.
        // 그렇게 하면 상태 관리자가 사용자에게 오류를 표시하여 적절하게 처리할 수 있습니다.
        rethrow;
      }
    }
  }

  Future<QuoteListPage> _getQuoteListPageFromNetwork(
    int pageNumber, {
    Tag? tag,
    String searchTerm = '',
    String? favoritedByUsername,
  }) async {
    try {
      final apiPage = await remoteApi.getQuoteListPage(
        pageNumber,
        tag: tag?.toRemoteModel(),
        searchTerm: searchTerm,
        favoritedByUsername: favoritedByUsername,
      );

      final isFiltering = tag != null || searchTerm.isNotEmpty;
      final favoritesOnly = favoritedByUsername != null;

      final shouldStoreOnCache = !isFiltering;
      // 3 필터링된 결과를 캐시하면 안 됩니다.
      // 사용자가 수행할 수 있는 모든 검색을 캐시하려고 하면 장치의 저장 공간이 빠르게 채워집니다.
      // 또한 사용자는 검색을 더 오래 기다릴 의향이 있습니다.
      if (shouldStoreOnCache) {
        // 4 새로운 첫 페이지 를 얻을 때마다 캐시에서 이전에 저장한 모든 후속 페이지를 제거해야 합니다.
        // 이렇게 하면 다음 페이지를 향후 네트워크에서 강제로 가져오므로
        // 업데이트된 페이지와 오래된 페이지를 혼합할 위험이 없습니다.
        // 이렇게 하지 않으면 문제가 발생할 수 있습니다.
        // 예를 들어 두 번째 페이지에 있던 인용문이 첫 번째 페이지로 이동한 경우
        // 캐시된 페이지와 새 페이지를 혼합하면 해당 인용문이 두 번 표시될 위험이 있습니다.
        final shouldEmptyCache = pageNumber == 1;
        if (shouldEmptyCache) {
          await _localStorage.clearQuoteListPageList(favoritesOnly);
        }

        final cachePage = apiPage.toCacheModel();
        await _localStorage.upsertQuoteListPage(
          pageNumber,
          cachePage,
          favoritesOnly,
        );
      }

      final domainPage = apiPage.toDomainModel();
      return domainPage;
    } on EmptySearchResultFavQsException catch (_) {
      throw EmptySearchResultException();
    }
  }

  Future<Quote> getQuoteDetails(int id) async {
    final cachedQuote = await _localStorage.getQuote(id);
    if (cachedQuote != null) {
      return cachedQuote.toDomainModel();
    } else {
      final apiQuote = await remoteApi.getQuote(id);
      final domainQuote = apiQuote.toDomainModel();
      return domainQuote;
    }
  }

  Future<Quote> favoriteQuote(int id) async {
    final updatedCacheQuote =
        await remoteApi.favoriteQuote(id).toCacheUpdateFuture(
              _localStorage,
              shouldInvalidateFavoritesCache: true,
            );
    return updatedCacheQuote.toDomainModel();
  }

  Future<Quote> unfavoriteQuote(int id) async {
    final updatedCacheQuote =
        await remoteApi.unfavoriteQuote(id).toCacheUpdateFuture(
              _localStorage,
              shouldInvalidateFavoritesCache: true,
            );
    return updatedCacheQuote.toDomainModel();
  }

  Future<Quote> upvoteQuote(int id) async {
    final updatedCacheQuote =
        await remoteApi.upvoteQuote(id).toCacheUpdateFuture(
              _localStorage,
            );
    return updatedCacheQuote.toDomainModel();
  }

  Future<Quote> downvoteQuote(int id) async {
    final updatedCacheQuote =
        await remoteApi.downvoteQuote(id).toCacheUpdateFuture(
              _localStorage,
            );
    return updatedCacheQuote.toDomainModel();
  }

  Future<Quote> unvoteQuote(int id) async {
    final updatedCacheQuote =
        await remoteApi.unvoteQuote(id).toCacheUpdateFuture(
              _localStorage,
            );
    return updatedCacheQuote.toDomainModel();
  }

  Future<void> clearCache() async {
    await _localStorage.clear();
  }
}

extension on Future<QuoteRM> {
  Future<QuoteCM> toCacheUpdateFuture(
    QuoteLocalStorage localStorage, {
    bool shouldInvalidateFavoritesCache = false,
  }) async {
    try {
      final updatedApiQuote = await this;
      final updatedCacheQuote = updatedApiQuote.toCacheModel();
      await Future.wait(
        [
          localStorage.updateQuote(
            updatedCacheQuote,
            !shouldInvalidateFavoritesCache,
          ),
          if (shouldInvalidateFavoritesCache)
            localStorage.clearQuoteListPageList(true),
        ],
      );
      return updatedCacheQuote;
    } catch (error) {
      if (error is UserAuthRequiredFavQsException) {
        throw UserAuthenticationRequiredException();
      }
      rethrow;
    }
  }
}

enum QuoteListPageFetchPolicy {
  cacheAndNetwork,
  networkOnly,
  networkPreferably,
  cachePreferably,
}
