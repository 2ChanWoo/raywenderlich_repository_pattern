import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quote_details/src/quote_details_cubit.dart';
import 'package:quote_repository/quote_repository.dart';
import 'package:share_plus/share_plus.dart';

typedef QuoteDetailsShareableLinkGenerator = Future<String> Function(
  Quote quote,
);

class QuoteDetailsScreen extends StatelessWidget {
  const QuoteDetailsScreen({
    required this.quoteId,
    required this.onAuthenticationError,
    required this.quoteRepository,
    this.shareableLinkGenerator,
    Key? key,
  }) : super(key: key);

  final int quoteId;
  final VoidCallback onAuthenticationError;
  final QuoteRepository quoteRepository;
  final QuoteDetailsShareableLinkGenerator? shareableLinkGenerator;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<QuoteDetailsCubit>(
      create: (_) => QuoteDetailsCubit(
        quoteId: quoteId,
        quoteRepository: quoteRepository,
      ),
      child: QuoteDetailsView(
        onAuthenticationError: onAuthenticationError,
        shareableLinkGenerator: shareableLinkGenerator,
      ),
    );
  }
}

@visibleForTesting
class QuoteDetailsView extends StatelessWidget {
  const QuoteDetailsView({
    required this.onAuthenticationError,
    this.shareableLinkGenerator,
    Key? key,
  }) : super(key: key);

  final VoidCallback onAuthenticationError;
  final QuoteDetailsShareableLinkGenerator? shareableLinkGenerator;

  @override
  Widget build(BuildContext context) {
    print("????????QuoteDetailsView???????????");
    return StyledStatusBar.dark(
      child: BlocConsumer<QuoteDetailsCubit, QuoteDetailsState>(  // consumer 는 BlocBuilder 와 BlocListner 를 합친 것과 같음.
        listener: (context, state) {
          print("Detail BlocConsumer state: $state");
          /// 아, Success 상태에서 뭔가 오류가 있을경우..?! Fail인건 Builder에서 처리되는거구..
          final quoteUpdateError =
              state is QuoteDetailsSuccess ? state.quoteUpdateError : null; //TODO: 웨 Success 인데 Error 로?? 디테일 나왔을경우만인건가?
          if (quoteUpdateError != null) {
            final snackBar =
                quoteUpdateError is UserAuthenticationRequiredException
                    ? const AuthenticationRequiredErrorSnackBar()
                    : const GenericErrorSnackBar();

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(snackBar);

            if (quoteUpdateError is UserAuthenticationRequiredException) {
              onAuthenticationError();
            }
          }
        },
        builder: (context, state) {
          print("Detail BlocConsumer Build");
          return WillPopScope(
            onWillPop: () async {
              print("버근가.. 왜 시스템 버튼으로는 안나오지?");
              final displayedQuote =
                  state is QuoteDetailsSuccess ? state.quote : null;

              Navigator.of(context).pop(displayedQuote);
              return false;
            },
            child: Scaffold(
              appBar: state is QuoteDetailsSuccess
                  ? _QuoteActionsAppBar(
                      quote: state.quote,
                      shareableLinkGenerator: shareableLinkGenerator,
                    )
                  : null,
              body: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(
                    WonderTheme.of(context).screenMargin,
                  ),
                  child: state is QuoteDetailsSuccess
                      ? _Quote(
                          quote: state.quote,
                        )
                      : state is QuoteDetailsFailure
                          ? ExceptionIndicator(
                              onTryAgain: () {
                                final cubit = context.read<QuoteDetailsCubit>();
                                cubit.refetch();
                              },
                            )
                          : const CenteredCircularProgressIndicator(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuoteActionsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _QuoteActionsAppBar({
    required this.quote,
    this.shareableLinkGenerator,
    Key? key,
  }) : super(key: key);

  final Quote quote;
  final QuoteDetailsShareableLinkGenerator? shareableLinkGenerator;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuoteDetailsCubit>();
    final shareableLinkGenerator = this.shareableLinkGenerator;
    return RowAppBar(
      children: [
        FavoriteIconButton(
          isFavorite: quote.isFavorite ?? false,
          onTap: () {
            if (quote.isFavorite == true) {
              cubit.unfavoriteQuote();
            } else {
              cubit.favoriteQuote();
            }
          },
        ),
        UpvoteIconButton(
          count: quote.upvotesCount,
          isUpvoted: quote.isUpvoted ?? false,
          onTap: () {
            if (quote.isUpvoted == true) {
              cubit.unvoteQuote();
            } else {
              cubit.upvoteQuote();
            }
          },
        ),
        DownvoteIconButton(
          count: quote.downvotesCount,
          isDownvoted: quote.isDownvoted ?? false,
          onTap: () {
            if (quote.isDownvoted == true) {
              cubit.unvoteQuote();
            } else {
              cubit.downvoteQuote();
            }
          },
        ),
        if (shareableLinkGenerator != null)
          ShareIconButton(
            onTap: () async {
              final url = await shareableLinkGenerator(quote);
              Share.share(
                url,
              );
            },
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _Quote extends StatelessWidget {
  static const double _quoteIconWidth = 46;

  const _Quote({
    required this.quote,
    Key? key,
  }) : super(key: key);

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final theme = WonderTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: OpeningQuoteSvgAsset(
            width: _quoteIconWidth,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.xxLarge,
            ),
            child: Center(
              child: ShrinkableText(
                quote.body,
                style: theme.quoteTextStyle.copyWith(
                  fontSize: FontSize.xxLarge,
                ),
              ),
            ),
          ),
        ),
        const ClosingQuoteSvgAsset(
          width: _quoteIconWidth,
        ),
        const SizedBox(
          height: Spacing.medium,
        ),
        Text(
          quote.author ?? '',
          style: const TextStyle(
            fontSize: FontSize.large,
          ),
        ),
      ],
    );
  }
}
