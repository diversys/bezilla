/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 2 -*-
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
 * Netscape Communications, Inc.
 * Portions created by the Initial Developer are Copyright (C) 1999
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Conrad Carlen <ccarlen@netscape.com>
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

#include <LWindow.h>
#include <LListener.h>
#include <LBroadcaster.h>

class CBrowserShell;
class LEditText;
class LStaticText;
class CThrobber;
class LProgressBar;
class LIconControl;


// CBrowserWindow:
// A simple browser window that hooks up a CBrowserShell to a minimal set of controls
// (Back, Forward and Stop buttons + URL field + status bar).


class CBrowserWindow :  public LWindow,
                        public LListener,
                        public LBroadcaster
{
private:
    typedef LWindow Inherited;

public:
    enum { class_ID = FOUR_CHAR_CODE('BroW') };

                                CBrowserWindow();
                                CBrowserWindow(LCommander*      inSuperCommander,
                                               const Rect&      inGlobalBounds,
                                               ConstStringPtr   inTitle,
                                               SInt16           inProcID,
                                               UInt32           inAttributes,
                                               WindowPtr        inBehind);
                                CBrowserWindow(LStream* inStream);

    virtual                     ~CBrowserWindow();

    virtual void                FinishCreateSelf();

    virtual void                ListenToMessage(MessageT        inMessage,
                                                 void*          ioParam);

    virtual Boolean             ObeyCommand(CommandT            inCommand,
                                            void                *ioParam);
                                    
protected:
    CBrowserShell*              mBrowserShell;
    
    LEditText*                  mURLField;
    LStaticText*                mStatusBar;
    CThrobber*                  mThrobber;
    LControl                    *mBackButton, *mForwardButton, *mReloadButton, *mStopButton;
    LProgressBar*               mProgressBar;
    LIconControl*               mLockIcon;
};

// ---------------------------------------------------------------------------
//  Global Functions
// ---------------------------------------------------------------------------

// Must be called at initialization time - after NS_InitEmbedding
nsresult InitializeWindowCreator();

