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
 * The Original Code is the Mozilla SVG project.
 *
 * The Initial Developer of the Original Code is
 * Crocodile Clips Ltd..
 * Portions created by the Initial Developer are Copyright (C) 2001
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Alex Fritze <alex.fritze@crocodile-clips.com> (original author)
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either of the GNU General Public License Version 2 or later (the "GPL"),
 * or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
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

#include "nsSVGPathGeometryFrame.h"
#include "nsIDOMSVGAnimatedLength.h"
#include "nsIDOMSVGLength.h"
#include "nsIDOMSVGPoint.h"
#include "nsIDOMSVGCircleElement.h"
#include "nsIDOMSVGElement.h"
#include "nsIDOMSVGSVGElement.h"
//#include "nsASVGPathBuilder.h"
#include "nsISVGRendererPathBuilder.h"
#include "nsLayoutAtoms.h"

class nsSVGCircleFrame : public nsSVGPathGeometryFrame
{
protected:
  friend nsresult
  NS_NewSVGCircleFrame(nsIPresShell* aPresShell, nsIContent* aContent, nsIFrame** aNewFrame);

  virtual ~nsSVGCircleFrame();
  NS_IMETHOD InitSVG();

public:
  /**
   * Get the "type" of the frame
   *
   * @see nsLayoutAtoms::svgCircleFrame
   */
  virtual nsIAtom* GetType() const;

#ifdef DEBUG
  NS_IMETHOD GetFrameName(nsAString& aResult) const
  {
    return MakeFrameName(NS_LITERAL_STRING("SVGCircle"), aResult);
  }
#endif

  // nsISVGValueObserver interface:
  NS_IMETHOD DidModifySVGObservable(nsISVGValue* observable,
                                    nsISVGValue::modificationType aModType);

  // nsISVGPathGeometrySource interface:
  NS_IMETHOD ConstructPath(nsISVGRendererPathBuilder *pathBuilder);

private:
  nsCOMPtr<nsIDOMSVGLength> mCx;
  nsCOMPtr<nsIDOMSVGLength> mCy;
  nsCOMPtr<nsIDOMSVGLength> mR;
};

//----------------------------------------------------------------------
// Implementation

nsresult
NS_NewSVGCircleFrame(nsIPresShell* aPresShell, nsIContent* aContent, nsIFrame** aNewFrame)
{
  *aNewFrame = nsnull;
  
  nsCOMPtr<nsIDOMSVGCircleElement> circle = do_QueryInterface(aContent);
  if (!circle) {
#ifdef DEBUG
    printf("warning: trying to construct an SVGCircleFrame for a content element that doesn't support the right interfaces\n");
#endif
    return NS_ERROR_FAILURE;
  }
  
  nsSVGCircleFrame* it = new (aPresShell) nsSVGCircleFrame;
  if (nsnull == it)
    return NS_ERROR_OUT_OF_MEMORY;

  *aNewFrame = it;
  return NS_OK;
}

nsSVGCircleFrame::~nsSVGCircleFrame()
{
  nsCOMPtr<nsISVGValue> value;
  if (mCx && (value = do_QueryInterface(mCx)))
      value->RemoveObserver(this);
  if (mCy && (value = do_QueryInterface(mCy)))
      value->RemoveObserver(this);
  if (mR && (value = do_QueryInterface(mR)))
      value->RemoveObserver(this);
}

NS_IMETHODIMP
nsSVGCircleFrame::InitSVG()
{
  nsresult rv = nsSVGPathGeometryFrame::InitSVG();
  if (NS_FAILED(rv)) return rv;

  
  nsCOMPtr<nsIDOMSVGCircleElement> circle = do_QueryInterface(mContent);
  NS_ASSERTION(circle,"wrong content element");

  {
    nsCOMPtr<nsIDOMSVGAnimatedLength> length;
    circle->GetCx(getter_AddRefs(length));
    length->GetAnimVal(getter_AddRefs(mCx));
    NS_ASSERTION(mCx, "no cx");
    if (!mCx) return NS_ERROR_FAILURE;
    nsCOMPtr<nsISVGValue> value = do_QueryInterface(mCx);
    if (value)
      value->AddObserver(this);
  }

  {
    nsCOMPtr<nsIDOMSVGAnimatedLength> length;
    circle->GetCy(getter_AddRefs(length));
    length->GetAnimVal(getter_AddRefs(mCy));
    NS_ASSERTION(mCx, "no cy");
    if (!mCx) return NS_ERROR_FAILURE;
    nsCOMPtr<nsISVGValue> value = do_QueryInterface(mCy);
    if (value)
      value->AddObserver(this);
  }

  {
    nsCOMPtr<nsIDOMSVGAnimatedLength> length;
    circle->GetR(getter_AddRefs(length));
    length->GetAnimVal(getter_AddRefs(mR));
    NS_ASSERTION(mCx, "no r");
    if (!mCx) return NS_ERROR_FAILURE;
    nsCOMPtr<nsISVGValue> value = do_QueryInterface(mR);
    if (value)
      value->AddObserver(this);
  }
  
  return NS_OK;
}  

nsIAtom *
nsSVGCircleFrame::GetType() const
{
  return nsLayoutAtoms::svgCircleFrame;
}

//----------------------------------------------------------------------
// nsISVGValueObserver methods:

NS_IMETHODIMP
nsSVGCircleFrame::DidModifySVGObservable(nsISVGValue* observable,
                                         nsISVGValue::modificationType aModType)
{
  nsCOMPtr<nsIDOMSVGLength> l = do_QueryInterface(observable);
  if (l && (mCx==l || mCy==l || mR==l)) {
    UpdateGraphic(nsISVGPathGeometrySource::UPDATEMASK_PATH);
    return NS_OK;
  }
  // else
  return nsSVGPathGeometryFrame::DidModifySVGObservable(observable, aModType);
}


//----------------------------------------------------------------------
// nsISVGPathGeometrySource methods:

/* void constructPath (in nsISVGRendererPathBuilder pathBuilder); */
NS_IMETHODIMP nsSVGCircleFrame::ConstructPath(nsISVGRendererPathBuilder* pathBuilder)
{
  float x,y,r;

  mCx->GetValue(&x);
  mCy->GetValue(&y);
  mR->GetValue(&r);

  // we should be able to build this as a single arc with startpoints
  // and endpoints infinitesimally separated. Let's use two arcs
  // though, so that the builder doesn't get confused:
  pathBuilder->Moveto(x, y-r);
  pathBuilder->Arcto(x-r, y  , r, r, 0.0, 0, 0);
  pathBuilder->Arcto(x  , y-r, r, r, 0.0, 1, 0);
  pathBuilder->ClosePath(&x,&y);
  
  return NS_OK;
}
