/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 *
 * ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is the Mozilla browser.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2002
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   william@dell.wisner.name (William Dell Wisner)
 *   josh@mozilla.com (Josh Aas)
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Sparkle/Sparkle.h>

#import "NSWorkspace+Utils.h"
#import "AppListMenuFactory.h"
#import "UserDefaults.h"

#import "General.h"

static const char kHomepagePrefName[] = "browser.startup.homepage";
static const char kNewPageActionPrefName[] = "browser.startup.page";
static const char kNewTabActionPrefName[] = "browser.tabs.startPage";
static const char kCheckDefaultBrowserPrefName[] = "camino.check_default_browser";
static const char kWarnWhenClosingPrefName[] = "camino.warn_when_closing";
static const char kRememberWindowStatePrefName[] = "camino.remember_window_state";

@interface OrgMozillaCaminoPreferenceGeneral(Private)

- (NSString*)currentHomePage;
- (void)updateDefaultBrowserMenu;
- (void)browserSelectionPanelDidEnd:(NSOpenPanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
- (void)feedSelectionPanelDidEnd:(NSOpenPanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;

@end

@implementation OrgMozillaCaminoPreferenceGeneral

- (id)initWithBundle:(NSBundle *)bundle
{
  if ((self = [super initWithBundle:bundle])) {
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[NSArray array] 
                                                                                        forKey:kUserChosenBrowserUserDefaultsKey]];
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[NSArray array]
                                                                                        forKey:kUserChosenFeedViewerUserDefaultsKey]];
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (void)mainViewDidLoad
{
  if (!mPrefService)
    return;

  BOOL gotPref;

  // 0: blank page. 1: home page. 2: last page visited. Our behaviour here should
  // match what the browser does when the prefs don't exist.
  if (([self getIntPref:kNewPageActionPrefName withSuccess:&gotPref] == 1) || !gotPref)
    [checkboxNewWindowBlank setState:NSOnState];

  if (([self getIntPref:kNewTabActionPrefName withSuccess:&gotPref] == 1))
    [checkboxNewTabBlank setState:NSOnState];

  if ([self getBooleanPref:kCheckDefaultBrowserPrefName withSuccess:&gotPref] || !gotPref)
    [checkboxCheckDefaultBrowserOnLaunch setState:NSOnState];

  if ([self getBooleanPref:kWarnWhenClosingPrefName withSuccess:&gotPref])
    [checkboxWarnWhenClosing setState:NSOnState];

  if ([self getBooleanPref:kRememberWindowStatePrefName withSuccess:&gotPref])
    [checkboxRememberWindowState setState:NSOnState];

  if ([[[NSUserDefaults standardUserDefaults] stringForKey:SUFeedURLKey] length] == 0) {
    // Disable update checking if there's no feed to check.  The tooltip comes
    // from the main application because it's used there too.
    [checkboxAutoUpdate setEnabled:NO];
    [checkboxAutoUpdate setToolTip:NSLocalizedString(@"AutoUpdateDisabledToolTip", @"")];
  }
  else if ([[NSUserDefaults standardUserDefaults] integerForKey:SUScheduledCheckIntervalKey] > 0) {
    [checkboxAutoUpdate setState:NSOnState];
  }


  [textFieldHomePage setStringValue:[self currentHomePage]];

  // set up default browser menu
  [self updateDefaultBrowserMenu];

  // set up the feed viewer menu
  [self updateDefaultFeedViewerMenu];

  // register notification if the default feed viewer is changed in the FeedServiceController
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(updateDefaultFeedViewerMenu)
                                               name:kDefaultFeedViewerChanged
                                             object:nil];
}

- (void) didUnselect
{
  if (!mPrefService)
    return;
  
  [self setPref:kHomepagePrefName toString:[textFieldHomePage stringValue]];
  
  // ensure that the prefs exist
  [self setPref:kNewPageActionPrefName toInt:[checkboxNewWindowBlank state] ? 1 : 0];
  [self setPref:kNewTabActionPrefName toInt:[checkboxNewTabBlank state] ? 1 : 0];
}

- (IBAction)checkboxStartPageClicked:(id)sender
{
  if (!mPrefService)
    return;

  const char* prefName = NULL;
  if (sender == checkboxNewTabBlank)
    prefName = kNewTabActionPrefName;
  else if (sender == checkboxNewWindowBlank)
    prefName = kNewPageActionPrefName;

  if (prefName)
    [self setPref:prefName toInt: [sender state] ? 1 : 0];
}

- (IBAction)warningCheckboxClicked:(id)sender
{
  if (sender == checkboxWarnWhenClosing)
    [self setPref:kWarnWhenClosingPrefName toBoolean:([sender state] == NSOnState)];
}

- (IBAction)rememberWindowStateCheckboxClicked:(id)sender
{
  if (sender == checkboxRememberWindowState)
    [self setPref:kRememberWindowStatePrefName toBoolean:([sender state] == NSOnState)];
}

- (IBAction)checkDefaultBrowserOnLaunchClicked:(id)sender
{
  if (sender == checkboxCheckDefaultBrowserOnLaunch)
    [self setPref:kCheckDefaultBrowserPrefName toBoolean:([sender state] == NSOnState)];
}

- (IBAction)autoUpdateCheckboxClicked:(id)sender
{
  if (sender == checkboxAutoUpdate) {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([sender state] == NSOnState) {
      [defaults setInteger:USER_DEFAULTS_UPDATE_INTERVAL_DEFAULT
                    forKey:SUScheduledCheckIntervalKey];
    }
    else {
      [defaults setInteger:0 forKey:SUScheduledCheckIntervalKey];
    }
  }
}

- (NSString*)currentHomePage
{
  BOOL gotPref;
  return [self getStringPref:kHomepagePrefName withSuccess:&gotPref];
}

// called when the users changes the selection in the default browser menu
- (IBAction)defaultBrowserChange:(id)sender
{
  [[AppListMenuFactory sharedAppListMenuFactory] validateAndRegisterDefaultBrowser:[sender representedObject]];
  [self updateDefaultBrowserMenu];
}

-(IBAction)defaultFeedViewerChange:(id)sender
{
  [[AppListMenuFactory sharedAppListMenuFactory] validateAndRegisterDefaultFeedViewer:[sender representedObject]];
  [self updateDefaultFeedViewerMenu];
}

-(IBAction)runOpenDialogToSelectBrowser:(id)sender
{
  NSOpenPanel *op = [NSOpenPanel openPanel];
  [op setCanChooseDirectories:NO];
  [op setAllowsMultipleSelection:NO];
  [op beginSheetForDirectory:nil
                        file:nil
                       types:[NSArray arrayWithObject:@"app"]
              modalForWindow:[defaultBrowserPopUp window]
               modalDelegate:self
              didEndSelector:@selector(browserSelectionPanelDidEnd:returnCode:contextInfo:)
                 contextInfo:nil];
}

-(IBAction)runOpenDialogToSelectFeedViewer:(id)sender
{
  NSOpenPanel *op = [NSOpenPanel openPanel];
  [op setCanChooseDirectories:NO];
  [op setAllowsMultipleSelection:NO];
  [op beginSheetForDirectory:nil
                        file:nil
                       types:[NSArray arrayWithObject:@"app"]
              modalForWindow:[defaultFeedViewerPopUp window]
               modalDelegate:self
              didEndSelector:@selector(feedSelectionPanelDidEnd:returnCode:contextInfo:)
                 contextInfo:nil];
}

- (void)browserSelectionPanelDidEnd:(NSOpenPanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSOKButton) {
    NSString *chosenBundleID = [[NSWorkspace sharedWorkspace] identifierForBundle:[[sheet URLs] objectAtIndex:0]];
    if (chosenBundleID) {
      // add this browser to a list of apps we should always consider as browsers
      NSMutableArray *userChosenBundleIDs = [NSMutableArray arrayWithCapacity:2];
      [userChosenBundleIDs addObjectsFromArray:[[NSUserDefaults standardUserDefaults] objectForKey:kUserChosenBrowserUserDefaultsKey]];
      if (![userChosenBundleIDs containsObject:chosenBundleID]) {
        [userChosenBundleIDs addObject:chosenBundleID];
        [[NSUserDefaults standardUserDefaults] setObject:userChosenBundleIDs forKey:kUserChosenBrowserUserDefaultsKey];
      }
      // make it the default browser
      [[NSWorkspace sharedWorkspace] setDefaultBrowserWithIdentifier:chosenBundleID];
    }
  }
  [self updateDefaultBrowserMenu];
}

- (void)feedSelectionPanelDidEnd:(NSOpenPanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSOKButton) {
    NSString* chosenBundleID = [[NSWorkspace sharedWorkspace] identifierForBundle:[[sheet URLs] objectAtIndex:0]];
    if (chosenBundleID) {
      // add this browser to a list of apps we should always consider as browsers
      NSMutableArray* userChosenBundleIDs = [NSMutableArray arrayWithCapacity:2];
      [userChosenBundleIDs addObjectsFromArray:[[NSUserDefaults standardUserDefaults] objectForKey:kUserChosenFeedViewerUserDefaultsKey]];
      if (![userChosenBundleIDs containsObject:chosenBundleID]) {
        [userChosenBundleIDs addObject:chosenBundleID];
        [[NSUserDefaults standardUserDefaults] setObject:userChosenBundleIDs forKey:kUserChosenFeedViewerUserDefaultsKey];
      }
      // set the default feed viewer
      [[NSWorkspace sharedWorkspace] setDefaultFeedViewerWithIdentifier:chosenBundleID];
      [self updateDefaultFeedViewerMenu];
    }
  }
  // The open action was cancelled, re-select the default application
  else
    [defaultFeedViewerPopUp selectItemAtIndex:0];
}

-(void)updateDefaultBrowserMenu
{
  [[AppListMenuFactory sharedAppListMenuFactory] buildBrowserAppsMenuForPopup:defaultBrowserPopUp 
                                                                    andAction:@selector(defaultBrowserChange:) 
                                                              andSelectAction:@selector(runOpenDialogToSelectBrowser:)
                                                                    andTarget:self];
}

-(void)updateDefaultFeedViewerMenu
{
  [[AppListMenuFactory sharedAppListMenuFactory] buildFeedAppsMenuForPopup:defaultFeedViewerPopUp
                                                                 andAction:@selector(defaultFeedViewerChange:)
                                                           andSelectAction:@selector(runOpenDialogToSelectFeedViewer:) 
                                                                 andTarget:self];
}

@end
