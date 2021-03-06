/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
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
 * The Original Code is TransforMiiX XSLT processor code.
 *
 * The Initial Developer of the Original Code is
 * The MITRE Corporation.
 * Portions created by the Initial Developer are Copyright (C) 1999
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Keith Visco <kvisco@ziplink.net> (Original Author)
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

/*
  Implementation of an XPath LocationStep
*/

#include "Expr.h"
#include "txIXPathContext.h"
#include "txNodeSet.h"

  //-----------------------------/
 //- Virtual methods from Expr -/
//-----------------------------/

/**
 * Evaluates this Expr based on the given context node and processor state
 * @param context the context node for evaluation of this Expr
 * @param ps the ProcessorState containing the stack information needed
 * for evaluation
 * @return the result of the evaluation
 * @see Expr
**/
nsresult
LocationStep::evaluate(txIEvalContext* aContext, txAExprResult** aResult)
{
    NS_ASSERTION(aContext, "internal error");
    *aResult = nsnull;

    nsRefPtr<txNodeSet> nodes;
    nsresult rv = aContext->recycler()->getNodeSet(getter_AddRefs(nodes));
    NS_ENSURE_SUCCESS(rv, rv);

    txXPathTreeWalker walker(aContext->getContextNode());

    switch (mAxisIdentifier) {
        case ANCESTOR_AXIS:
        {
            if (!walker.moveToParent()) {
                break;
            }
            // do not break here
        }
        case ANCESTOR_OR_SELF_AXIS:
        {
            nodes->setReverse();

            do {
                if (mNodeTest->matches(walker.getCurrentPosition(), aContext)) {
                    nodes->append(walker.getCurrentPosition());
                }
            } while (walker.moveToParent());

            break;
        }
        case ATTRIBUTE_AXIS:
        {
            if (!walker.moveToFirstAttribute()) {
                break;
            }

            do {
                if (mNodeTest->matches(walker.getCurrentPosition(), aContext)) {
                    nodes->append(walker.getCurrentPosition());
                }
            } while (walker.moveToNextAttribute());
            break;
        }
        case DESCENDANT_OR_SELF_AXIS:
        {
            if (mNodeTest->matches(walker.getCurrentPosition(), aContext)) {
                nodes->append(walker.getCurrentPosition());
            }
            // do not break here
        }
        case DESCENDANT_AXIS:
        {
            fromDescendants(walker.getCurrentPosition(), aContext, nodes);
            break;
        }
        case FOLLOWING_AXIS:
        {
            if (txXPathNodeUtils::isAttribute(walker.getCurrentPosition())) {
                walker.moveToParent();
                fromDescendants(walker.getCurrentPosition(), aContext, nodes);
            }
            PRBool cont = PR_TRUE;
            while (!walker.moveToNextSibling()) {
                if (!walker.moveToParent()) {
                    cont = PR_FALSE;
                    break;
                }
            }
            while (cont) {
                if (mNodeTest->matches(walker.getCurrentPosition(), aContext)) {
                    nodes->append(walker.getCurrentPosition());
                }

                fromDescendants(walker.getCurrentPosition(), aContext, nodes);

                while (!walker.moveToNextSibling()) {
                    if (!walker.moveToParent()) {
                        cont = PR_FALSE;
                        break;
                    }
                }
            }
            break;
        }
        case FOLLOWING_SIBLING_AXIS:
        {
            while (walker.moveToNextSibling()) {
                if (mNodeTest->matches(walker.getCurrentPosition(), aContext)) {
                    nodes->append(walker.getCurrentPosition());
                }
            }
            break;
        }
        case NAMESPACE_AXIS: //-- not yet implemented
#if 0
            // XXX DEBUG OUTPUT
            cout << "namespace axis not yet implemented"<<endl;
#endif
            break;
        case PARENT_AXIS :
        {
            if (walker.moveToParent() &&
                mNodeTest->matches(walker.getCurrentPosition(), aContext)) {
                nodes->append(walker.getCurrentPosition());
            }
            break;
        }
        case PRECEDING_AXIS:
        {
            nodes->setReverse();

            PRBool cont = PR_TRUE;
            while (!walker.moveToPreviousSibling()) {
                if (!walker.moveToParent()) {
                    cont = PR_FALSE;
                    break;
                }
            }
            while (cont) {
                fromDescendantsRev(walker.getCurrentPosition(), aContext, nodes);

                if (mNodeTest->matches(walker.getCurrentPosition(), aContext)) {
                    nodes->append(walker.getCurrentPosition());
                }

                while (!walker.moveToPreviousSibling()) {
                    if (!walker.moveToParent()) {
                        cont = PR_FALSE;
                        break;
                    }
                }
            }
            break;
        }
        case PRECEDING_SIBLING_AXIS:
        {
            nodes->setReverse();

            while (walker.moveToPreviousSibling()) {
                if (mNodeTest->matches(walker.getCurrentPosition(), aContext)) {
                    nodes->append(walker.getCurrentPosition());
                }
            }
            break;
        }
        case SELF_AXIS:
        {
            if (mNodeTest->matches(walker.getCurrentPosition(), aContext)) {
                nodes->append(walker.getCurrentPosition());
            }
            break;
        }
        default: // Children Axis
        {
            if (!walker.moveToFirstChild()) {
                break;
            }

            do {
                if (mNodeTest->matches(walker.getCurrentPosition(), aContext)) {
                    nodes->append(walker.getCurrentPosition());
                }
            } while (walker.moveToNextSibling());
            break;
        }
    }

    // Apply predicates
    if (!isEmpty()) {
        rv = evaluatePredicates(nodes, aContext);
        NS_ENSURE_SUCCESS(rv, rv);
    }

    nodes->unsetReverse();

    NS_ADDREF(*aResult = nodes);

    return NS_OK;
}

void LocationStep::fromDescendants(const txXPathNode& aNode,
                                   txIMatchContext* aCs,
                                   txNodeSet* aNodes)
{
    txXPathTreeWalker walker(aNode);
    if (!walker.moveToFirstChild()) {
        return;
    }

    do {
        const txXPathNode& child = walker.getCurrentPosition();
        if (mNodeTest->matches(child, aCs)) {
            aNodes->append(child);
        }
        fromDescendants(child, aCs, aNodes);
    } while (walker.moveToNextSibling());
}

void LocationStep::fromDescendantsRev(const txXPathNode& aNode,
                                      txIMatchContext* aCs,
                                      txNodeSet* aNodes)
{
    txXPathTreeWalker walker(aNode);
    if (!walker.moveToLastChild()) {
        return;
    }

    do {
        const txXPathNode& child = walker.getCurrentPosition();
        fromDescendantsRev(child, aCs, aNodes);

        if (mNodeTest->matches(child, aCs)) {
            aNodes->append(child);
        }

    } while (walker.moveToPreviousSibling());
}

#ifdef TX_TO_STRING
void
LocationStep::toString(nsAString& str)
{
    switch (mAxisIdentifier) {
        case ANCESTOR_AXIS :
            str.AppendLiteral("ancestor::");
            break;
        case ANCESTOR_OR_SELF_AXIS :
            str.AppendLiteral("ancestor-or-self::");
            break;
        case ATTRIBUTE_AXIS:
            str.Append(PRUnichar('@'));
            break;
        case DESCENDANT_AXIS:
            str.AppendLiteral("descendant::");
            break;
        case DESCENDANT_OR_SELF_AXIS:
            str.AppendLiteral("descendant-or-self::");
            break;
        case FOLLOWING_AXIS :
            str.AppendLiteral("following::");
            break;
        case FOLLOWING_SIBLING_AXIS:
            str.AppendLiteral("following-sibling::");
            break;
        case NAMESPACE_AXIS:
            str.AppendLiteral("namespace::");
            break;
        case PARENT_AXIS :
            str.AppendLiteral("parent::");
            break;
        case PRECEDING_AXIS :
            str.AppendLiteral("preceding::");
            break;
        case PRECEDING_SIBLING_AXIS :
            str.AppendLiteral("preceding-sibling::");
            break;
        case SELF_AXIS :
            str.AppendLiteral("self::");
            break;
        default:
            break;
    }
    NS_ASSERTION(mNodeTest, "mNodeTest is null, that's verboten");
    mNodeTest->toString(str);

    PredicateList::toString(str);
}
#endif
