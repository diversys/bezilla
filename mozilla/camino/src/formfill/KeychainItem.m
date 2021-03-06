/* -*- Mode: C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
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
 * The Original Code is Camino code.
 *
 * The Initial Developer of the Original Code is
 * Stuart Morgan
 * Portions created by the Initial Developer are Copyright (C) 2006
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Stuart Morgan <stuart.morgan@gmail.com>
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

#import "KeychainItem.h"

// Prior to 10.5, we can't use kSecLabelItemAttr due to a bug in Keychain
// Services (see bug 420665). The recommendation from Apple is to use the raw
// index instead of the attribute, which for password items is 7.
// Once we are 10.5+, we can just use kSecLabelItemAttr instead.
static const unsigned int kRawKeychainLabelIndex = 7;

static NSString* sPasswordsNotSavedMarkerAccount = nil;

@interface KeychainItem(Private)
+ (NSString*)labelForHost:(NSString*)host username:(NSString*)username;
- (KeychainItem*)initWithRef:(SecKeychainItemRef)ref;
- (void)loadKeychainData;
- (void)loadKeychainPassword;
- (OSStatus)setAttributeType:(SecKeychainAttrType)type
                    toString:(NSString*)value;
- (OSStatus)setAttributeType:(SecKeychainAttrType)type
                     toValue:(void*)valuePtr
                  withLength:(UInt32)length;
@end

@implementation KeychainItem

+ (void)initialize
{
  if (!sPasswordsNotSavedMarkerAccount)
    sPasswordsNotSavedMarkerAccount = [[NSString alloc] initWithFormat:@"Passwords%Cnot%Csaved", 0xA0, 0xA0];
}

+ (KeychainItem*)keychainItemForHost:(NSString*)host
                            username:(NSString*)username
                                port:(UInt16)port
                            protocol:(SecProtocolType)protocol
                  authenticationType:(SecAuthenticationType)authType
{
  SecKeychainItemRef itemRef;
  const char* serverName = [host UTF8String];
  UInt32 serverNameLength = serverName ? strlen(serverName) : 0;
  const char* accountName = [username UTF8String];
  UInt32 accountNameLength = accountName ? strlen(accountName) : 0;
  OSStatus result = SecKeychainFindInternetPassword(NULL, serverNameLength, serverName,
                                                    0, NULL, accountNameLength, accountName,
                                                    0, NULL, port, protocol, authType,
                                                    NULL, NULL, &itemRef);
  if (result != noErr)
      return nil;

  return [[[KeychainItem alloc] initWithRef:itemRef] autorelease];
}

// Returns an array of all keychain items matching the given criteria.
+ (NSArray*)allKeychainItemsForHost:(NSString*)host
                               port:(UInt16)port
                           protocol:(SecProtocolType)protocol
                 authenticationType:(SecAuthenticationType)authType
                            creator:(OSType)creator
{
  SecKeychainAttribute attributes[5];
  unsigned int usedAttributes = 0;

  const char* hostString = [host UTF8String];
  if (hostString) {
    attributes[usedAttributes].tag = kSecServerItemAttr;
    attributes[usedAttributes].data = (void*)(hostString);
    attributes[usedAttributes].length = strlen(hostString);
    ++usedAttributes;
  }
  if (protocol) {
    attributes[usedAttributes].tag = kSecProtocolItemAttr;
    attributes[usedAttributes].data = (void*)(&protocol);
    attributes[usedAttributes].length = sizeof(protocol);
    ++usedAttributes;
  }
  if (authType) {
    attributes[usedAttributes].tag = kSecAuthenticationTypeItemAttr;
    attributes[usedAttributes].data = (void*)(&authType);
    attributes[usedAttributes].length = sizeof(authType);
    ++usedAttributes;
  }
  if (creator) {
    attributes[usedAttributes].tag = kSecCreatorItemAttr;
    attributes[usedAttributes].data = (void*)(&creator);
    attributes[usedAttributes].length = sizeof(creator);
    ++usedAttributes;
  }

  SecKeychainAttributeList searchCriteria;
  searchCriteria.count = usedAttributes;
  searchCriteria.attr = attributes;

  SecKeychainSearchRef searchRef;
  OSStatus result = SecKeychainSearchCreateFromAttributes(NULL,
                                                          kSecInternetPasswordItemClass,
                                                          &searchCriteria,
                                                          &searchRef);
  if (result != noErr) {
    NSLog(@"Keychain search for host '%@' failed (error %d)", host, result);
    return nil;
  }

  NSMutableArray* matchingItems = [NSMutableArray array];
  SecKeychainItemRef keychainItemRef;
  while ((result = SecKeychainSearchCopyNext(searchRef, &keychainItemRef)) == noErr) {
    [matchingItems addObject:[[[KeychainItem alloc] initWithRef:keychainItemRef] autorelease]];
  }
  CFRelease(searchRef);

  // Safari (and possibly others) store some things without ports, so we always
  // search without a port. If any results match the port we wanted then
  // discard all the other results; if not discard any non-generic entries
  if (port != kAnyPort) {
    NSMutableArray* exactMatches = [NSMutableArray array];
    for (int i = [matchingItems count] - 1; i >= 0; --i) {
      KeychainItem* item = [matchingItems objectAtIndex:i];
      if ([item port] == port)
        [exactMatches insertObject:item atIndex:0];
      else if ([item port] != kAnyPort)
        [matchingItems removeObjectAtIndex:i];
    }
    if ([exactMatches count] > 0)
      matchingItems = exactMatches;
  }

  return matchingItems;
}

+ (KeychainItem*)addKeychainItemForHost:(NSString*)host
                                   port:(UInt16)port
                               protocol:(SecProtocolType)protocol
                     authenticationType:(SecAuthenticationType)authType
                           withUsername:(NSString*)username
                               password:(NSString*)password
{
  const char* serverName = [host UTF8String];
  UInt32 serverLength = serverName ? strlen(serverName) : 0;
  const char* accountName = [username UTF8String];
  UInt32 accountLength = accountName ? strlen(accountName) : 0;
  const char* passwordData = [password UTF8String];
  UInt32 passwordLength = passwordData ? strlen(passwordData) : 0;
  SecKeychainItemRef keychainItemRef;
  OSStatus result = SecKeychainAddInternetPassword(NULL, serverLength, serverName, 0, NULL,
                                                   accountLength, accountName, 0, NULL,
                                                   (UInt16)port, protocol, authType,
                                                   passwordLength, passwordData, &keychainItemRef);
  if (result != noErr) {
    NSLog(@"Couldn't add keychain item for %@ (error %d)", host, result);
    return nil;
  }

  KeychainItem* item = [[[KeychainItem alloc] initWithRef:keychainItemRef] autorelease];
  if (authType == kSecAuthenticationTypeHTMLForm) {
    [item setAttributeType:kSecDescriptionItemAttr
                  toString:NSLocalizedString(@"WebFormPassword", nil)];
  }
  [item setLabel:[KeychainItem labelForHost:host username:username]];

  return item;
}

- (KeychainItem*)initWithRef:(SecKeychainItemRef)ref
{
  if ((self = [super init])) {
    mKeychainItemRef = ref;
    mDataLoaded = NO;
  }
  return self;
}

- (void)dealloc
{
  if (mKeychainItemRef)
    CFRelease(mKeychainItemRef);
  [mUsername release];
  [mPassword release];
  [mHost release];
  [mComment release];
  [mSecurityDomain release];
  [mLabel release];
  [super dealloc];
}

- (void)loadKeychainData
{
  if (!mKeychainItemRef)
    return;
  SecKeychainAttributeInfo attrInfo;
  UInt32 tags[9];
  tags[0] = kSecAccountItemAttr;
  tags[1] = kSecServerItemAttr;
  tags[2] = kSecPortItemAttr;
  tags[3] = kSecProtocolItemAttr;
  tags[4] = kSecAuthenticationTypeItemAttr;
  tags[5] = kSecSecurityDomainItemAttr;
  tags[6] = kSecCreatorItemAttr;
  tags[7] = kSecCommentItemAttr;
  tags[8] = kRawKeychainLabelIndex;
  attrInfo.count = sizeof(tags)/sizeof(UInt32);
  attrInfo.tag = tags;
  attrInfo.format = NULL;

  SecKeychainAttributeList *attrList;
  OSStatus result = SecKeychainItemCopyAttributesAndData(mKeychainItemRef, &attrInfo, NULL,
                                                         &attrList, NULL, NULL);

  [mUsername autorelease];
  mUsername = nil;
  [mHost autorelease];
  mHost = nil;
  [mComment autorelease];
  mComment = nil;
  [mSecurityDomain autorelease];
  mSecurityDomain = nil;
  [mLabel autorelease];
  mLabel = nil;

  if (result != noErr) {
    NSLog(@"Couldn't load keychain data (error %d)", result);
    mUsername = [[NSString alloc] init];
    mHost = [[NSString alloc] init];
    mComment = [[NSString alloc] init];
    mSecurityDomain = [[NSString alloc] init];
    return;
  }

  for (unsigned int i = 0; i < attrList->count; i++) {
    SecKeychainAttribute attr = attrList->attr[i];
    if (attr.tag == kSecAccountItemAttr) {
      mUsername = attr.data ? [[NSString alloc] initWithBytes:(char*)(attr.data)
                                                       length:attr.length
                                                     encoding:NSUTF8StringEncoding] : @"";
    }
    else if (attr.tag == kSecServerItemAttr) {
      mHost = attr.data ? [[NSString alloc] initWithBytes:(char*)(attr.data)
                                                   length:attr.length
                                                 encoding:NSUTF8StringEncoding] : @"";
    }
    else if (attr.tag == kSecCommentItemAttr) {
      mComment = attr.data ? [[NSString alloc] initWithBytes:(char*)(attr.data)
                                                      length:attr.length
                                                    encoding:NSUTF8StringEncoding] : @"";
    }
    else if (attr.tag == kSecSecurityDomainItemAttr) {
      mSecurityDomain = attr.data ? [[NSString alloc] initWithBytes:(char*)(attr.data)
                                                             length:attr.length
                                                           encoding:NSUTF8StringEncoding] : @"";
    }
    else if (attr.tag == kRawKeychainLabelIndex || attr.tag == kSecLabelItemAttr) {
      mLabel = attr.data ? [[NSString alloc] initWithBytes:(char*)(attr.data)
                                                    length:attr.length
                                                  encoding:NSUTF8StringEncoding] : @"";
    }
    else if (attr.tag == kSecPortItemAttr) {
      mPort = attr.data ? *((UInt16*)(attr.data)) : kAnyPort;
    }
    else if (attr.tag == kSecProtocolItemAttr) {
      mProtocol = attr.data ? *((SecProtocolType*)(attr.data)) : 0;
    }
    else if (attr.tag == kSecAuthenticationTypeItemAttr) {
      mAuthenticationType = attr.data ? *((SecAuthenticationType*)(attr.data)) : 0;
    }
    else if (attr.tag == kSecCreatorItemAttr) {
      mCreator = attr.data ? *((OSType*)(attr.data)) : 0;
    }
  }
  SecKeychainItemFreeAttributesAndData(attrList, NULL);
  mDataLoaded = YES;
}

// Password is fetched separately, since trying to read the password will
// trigger an auth request if we aren't on the trust list.
- (void)loadKeychainPassword
{
  if (!mKeychainItemRef)
    return;
  UInt32 passwordLength;
  char* passwordData;
  OSStatus result = SecKeychainItemCopyAttributesAndData(mKeychainItemRef, NULL, NULL, NULL,
                                                         &passwordLength, (void**)(&passwordData));
  
  [mPassword autorelease];
  mPassword = nil;
  
  if (result == noErr) {
    mPassword = [[NSString alloc] initWithBytes:passwordData
                                         length:passwordLength
                                       encoding:NSUTF8StringEncoding];
    SecKeychainItemFreeAttributesAndData(NULL, (void*)passwordData);
  }
  else {
    // Being denied access isn't a failure case, so don't log it.
    if (result != errSecAuthFailed)
      NSLog(@"Couldn't load keychain data (error %d)", result);
  }
  // Mark it as loaded either way, so that we can return nil password as an
  // indicator that the item is inaccessible.
  mPasswordLoaded = YES;
}

- (NSString*)username
{
  if (!mDataLoaded)
    [self loadKeychainData];
  return mUsername;
}

- (NSString*)password
{
  if (!mPasswordLoaded)
    [self loadKeychainPassword];
  return mPassword;
}

- (void)setUsername:(NSString*)username password:(NSString*)password
{
  NSString* oldUsernameLabel = [KeychainItem labelForHost:[self host] username:[self username]];
  SecKeychainAttribute user;
  user.tag = kSecAccountItemAttr;
  const char* usernameString = [username UTF8String];
  user.data = (void*)usernameString;
  user.length = user.data ? strlen(user.data) : 0;
  SecKeychainAttributeList attrList;
  attrList.count = 1;
  attrList.attr = &user;
  const char* passwordData = [password UTF8String];
  UInt32 passwordLength = passwordData ? strlen(passwordData) : 0;
  OSStatus result = SecKeychainItemModifyAttributesAndData(mKeychainItemRef,
                                                           &attrList,
                                                           passwordLength,
                                                           passwordData);
  if (result != noErr) {
    NSLog(@"Couldn't update keychain item user and password for %@ (error %d)",
          username, result);
    return;
  }
  [mUsername autorelease];
  mUsername = [username copy];
  [mPassword autorelease];
  mPassword = [password copy];
  NSString* currentLabel = [self label];
  if (![currentLabel length] || [currentLabel isEqualToString:oldUsernameLabel])
    [self setLabel:[KeychainItem labelForHost:[self host] username:username]];
}

- (NSString*)host
{
  if (!mDataLoaded)
    [self loadKeychainData];
  return mHost;
}

- (void)setHost:(NSString*)host
{
  NSString* oldHostLabel = [KeychainItem labelForHost:[self host] username:[self username]];
  OSStatus result = [self setAttributeType:kSecServerItemAttr toString:host];
  if (result != noErr) {
    NSLog(@"Couldn't update keychain item host (error %d)", result);
    return;
  }
  [mHost autorelease];
  mHost = [host copy];
  NSString* currentLabel = [self label];
  if (![currentLabel length] || [currentLabel isEqualToString:oldHostLabel])
    [self setLabel:[KeychainItem labelForHost:host username:[self username]]];
}

- (UInt16)port
{
  if (!mDataLoaded)
    [self loadKeychainData];
  return mPort;
}

- (void)setPort:(UInt16)port
{
  OSStatus result = [self setAttributeType:kSecPortItemAttr
                                   toValue:&port
                                withLength:sizeof(UInt16)];
  if (result != noErr) {
    NSLog(@"Couldn't update keychain item port (error %d)", result);
    return;
  }
  mPort = port;
}

- (SecProtocolType)protocol
{
  if (!mDataLoaded)
    [self loadKeychainData];
  return mProtocol;
}

- (void)setProtocol:(SecProtocolType)protocol
{
  OSStatus result = [self setAttributeType:kSecProtocolItemAttr
                                   toValue:&protocol
                                withLength:sizeof(SecProtocolType)];
  if (result != noErr) {
    NSLog(@"Couldn't update keychain item protocol (error %d)", result);
    return;
  }
  mProtocol = protocol;
}

- (SecAuthenticationType)authenticationType
{
  if (!mDataLoaded)
    [self loadKeychainData];
  return mAuthenticationType;
}

- (void)setAuthenticationType:(SecAuthenticationType)authType
{
  OSStatus result = [self setAttributeType:kSecAuthenticationTypeItemAttr
                                   toValue:&authType
                                withLength:sizeof(SecAuthenticationType)];
  if (result != noErr) {
    NSLog(@"Couldn't update keychain item auth type (error %d)", result);
    return;
  }
  mAuthenticationType = authType;
  if (authType == kSecAuthenticationTypeHTMLForm) {
    [self setAttributeType:kSecDescriptionItemAttr
                  toString:NSLocalizedString(@"WebFormPassword", nil)];
  }
  else {
    [self setAttributeType:kSecDescriptionItemAttr toString:nil];
  }
}

- (OSType)creator
{
  if (!mDataLoaded)
    [self loadKeychainData];
  return mCreator;
}

- (void)setCreator:(OSType)creator
{
  OSStatus result = [self setAttributeType:kSecCreatorItemAttr
                                   toValue:&creator
                                withLength:sizeof(OSType)];
  if (result != noErr) {
    NSLog(@"Couldn't update keychain item creator (error %d)", result);
    return;
  }
  mCreator = creator;
}

- (NSString*)comment
{
  if (!mDataLoaded)
    [self loadKeychainData];
  return mComment;
}

- (void)setComment:(NSString*)comment
{
  OSStatus result = [self setAttributeType:kSecCommentItemAttr toString:comment];
  if (result != noErr) {
    NSLog(@"Couldn't update keychain item comment (error %d)", result);
    return;
  }
  [mComment autorelease];
  mComment = [comment copy];
}

- (NSString*)securityDomain
{
  if (!mDataLoaded)
    [self loadKeychainData];
  return mSecurityDomain;
}

 - (void)setSecurityDomain:(NSString*)securityDomain
{
  OSStatus result = [self setAttributeType:kSecSecurityDomainItemAttr
                                  toString:securityDomain];
  if (result != noErr) {
    NSLog(@"Couldn't update keychain item security domains (error %d)", result);
    return;
  }
  [mSecurityDomain autorelease];
  mSecurityDomain = [securityDomain copy];
}

- (NSString*)label
{
  if (!mDataLoaded)
    [self loadKeychainData];
  return mLabel;
}

 - (void)setLabel:(NSString*)label
{
  OSStatus result = [self setAttributeType:kRawKeychainLabelIndex toString:label];
  if (result != noErr) {
    NSLog(@"Couldn't update keychain item label (error %d)", result);
    return;
  }
  [mLabel autorelease];
  mLabel = [label copy];
}

- (OSStatus)setAttributeType:(SecKeychainAttrType)type
                    toString:(NSString*)value
{
  const char* cString = [value UTF8String];
  UInt32 length = cString ? strlen(cString) : 0;
  return [self setAttributeType:type toValue:(void*)cString withLength:length];
}

- (OSStatus)setAttributeType:(SecKeychainAttrType)type
                     toValue:(void*)valuePtr
                  withLength:(UInt32)length
{
  SecKeychainAttribute attr;
  attr.tag = type;
  attr.data = valuePtr;
  attr.length = length;
  SecKeychainAttributeList attrList;
  attrList.count = 1;
  attrList.attr = &attr;
  return SecKeychainItemModifyAttributesAndData(mKeychainItemRef, &attrList,
                                                0, NULL);
}

- (BOOL)isNonEntry
{
  // In theory, this would just be a check for kSecNegativeItemAttr. In practice
  // nobody seems to actually use that, so we have to use more fragile methods.
  // We don't use the password partly because browsers don't agree on that
  // (Safari uses " ", OmniWeb uses ""), and partly because this lets us
  // determine whether to ignore it without triggering an auth dialog.
  return ([[self username] isEqualToString:sPasswordsNotSavedMarkerAccount]);
}

- (void)removeFromKeychain
{
  SecKeychainItemDelete(mKeychainItemRef);
}

+ (NSString*)labelForHost:(NSString*)host username:(NSString*)username
{
  // KeychainLabelFormat takes host, username (e.g., "%1$@ (%2$@)")
  return [NSString stringWithFormat:NSLocalizedString(@"KeychainLabelFormat", nil),
                                    host, username];
}

@end
