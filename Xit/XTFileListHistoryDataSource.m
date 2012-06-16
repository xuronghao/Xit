//
//  XTFileListHistoryDataSource.m
//  Xit
//
//  Created by German Laullon on 15/09/11.
//

#import "XTFileListHistoryDataSource.h"
#import "XTRepository.h"
#import "XTHistoryItem.h"

// TODO: this class is similar to 'XTHistoryDataSource'... refactor both in a future.

@implementation XTFileListHistoryDataSource
@synthesize items;

- (id)init {
    self = [super init];
    if (self) {
        items = [NSMutableArray array];
        index = [NSMutableDictionary dictionary];
    }

    return self;
}

- (void)setRepo:(XTRepository *)newRepo {
    repo = newRepo;
    [repo addObserver:self forKeyPath:@"reload" options:NSKeyValueObservingOptionNew context:nil];
    [repo addObserver:self forKeyPath:@"selectedCommit" options:NSKeyValueObservingOptionNew context:nil];
    [self reload];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"reload"]) {
        NSArray *reload = [change objectForKey:NSKeyValueChangeNewKey];
        for (NSString *path in reload) {
            if ([path hasPrefix:@".git/logs/"]) {
                [self reload];
                break;
            }
        }
    } else if ([keyPath isEqualToString:@"selectedCommit"]) {
        NSString *newSelectedCommit = [change objectForKey:NSKeyValueChangeNewKey];
        XTHistoryItem *item = [index objectForKey:newSelectedCommit];
        if (item != nil) {
            [table selectRowIndexes:[NSIndexSet indexSetWithIndex:item.index] byExtendingSelection:NO];
            [table scrollRowToVisible:item.index];
        } else {
            NSLog(@"commit '%@' not found!!", newSelectedCommit);
        }
    }
}

- (void)reload {
    if (repo == nil)
        return;
    dispatch_async(repo.queue, ^{
                       NSMutableArray *newItems = [NSMutableArray array];
                       __block int idx = 0;

                       [repo    getCommitsWithArgs:[NSArray arrayWithObjects:@"--pretty=format:%H%n%h%n%ct%n%ce%n%s", @"--tags", @"--all", @"--topo-order", nil]
                        enumerateCommitsUsingBlock:^(NSString * line) {

                            NSArray *comps = [line componentsSeparatedByString:@"\n"];
                            // If Guard Malloc is on, it pollutes the output
                            if ([[comps objectAtIndex:0] hasPrefix:@"GuardMalloc["]) {
                                NSMutableArray *filteredComps = [comps mutableCopy];
                                while ([[filteredComps objectAtIndex:0] hasPrefix:@"GuardMalloc["])
                                [filteredComps removeObjectAtIndex:0];
                                comps = filteredComps;
                            }
                            XTHistoryItem *item = [[XTHistoryItem alloc] init];
                            if ([comps count] == 5) {
                                item.sha = [comps objectAtIndex:0];
                                item.shortSha = [comps objectAtIndex:1];
                                item.date = [comps objectAtIndex:2];
                                item.email = [comps objectAtIndex:3];
                                item.subject = [comps objectAtIndex:4];
                                item.index = idx++;
                                [newItems addObject:item];
                                [index setObject:item forKey:item.sha];
                            } else {
                                [NSException raise:@"Invalid commint" format:@"Line ***\n%@\n*** is invalid", line];
                            }

                        }
                                             error:nil];

                       NSLog (@"-> %lu", [newItems count]);
                       items = newItems;
                       [table reloadData];
                   });
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [items count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    XTHistoryItem *item = [items objectAtIndex:rowIndex];

    return item.shortSha;
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    NSLog(@"%@", aNotification);
    XTHistoryItem *item = [items objectAtIndex:table.selectedRow];
    repo.selectedCommit = item.sha;
}

@end
