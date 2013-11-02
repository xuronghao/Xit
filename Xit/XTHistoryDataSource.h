#import <Foundation/Foundation.h>

@class XTRepository;
@class XTHistoryItem;

/**
  Data source for the history list.
 */
@interface XTHistoryDataSource
    : NSObject<NSTableViewDataSource, NSTableViewDelegate> {
 @private
  XTRepository *repo;
  NSArray *items;
  IBOutlet NSTableView *table;
  NSMutableDictionary *index;
}

@property(readonly) NSArray *items;

- (void)reload;
- (void)setRepo:(XTRepository *)newRepo;
@end

