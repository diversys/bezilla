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
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 1998
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Ilya Konstantinov (mozilla-code@future.shiny.co.il)
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

#ifndef nsDOMMouseEvent_h__
#define nsDOMMouseEvent_h__

#include "nsIDOMMouseEvent.h"
#include "nsDOMUIEvent.h"

class nsIContent;
class nsIScrollableView;
class nsEvent;

class nsDOMMouseEvent : public nsIDOMMouseEvent,
                        public nsDOMUIEvent
{
public:
  nsDOMMouseEvent(nsPresContext* aPresContext, nsInputEvent* aEvent);

  NS_DECL_ISUPPORTS_INHERITED

  // nsIDOMMouseEvent Interface
  NS_DECL_NSIDOMMOUSEEVENT
  
  // Forward to base class
  NS_FORWARD_TO_NSDOMUIEVENT

  // Specific implementation for a mouse event.
  NS_IMETHOD GetWhich(PRUint32 *aWhich);

protected:
  // These are used for internal data for user created events
  PRInt16 mButton;
};

#endif // nsDOMMouseEvent_h__
