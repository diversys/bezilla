// LdapView.cpp : implementation of the LdapView class
//

#include "stdafx.h"
#include "ldap.h"
#include "winldap.h"

#include "LdapDoc.h"
#include "LdapView.h"
#include "PropDlg.h"

#ifdef _DEBUG
#ifdef _WIN32
#define new DEBUG_NEW
#endif
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// LdapView

IMPLEMENT_DYNCREATE(LdapView, CView)

BEGIN_MESSAGE_MAP(LdapView, CView)
	//{{AFX_MSG_MAP(LdapView)
	ON_WM_SIZE()
	ON_LBN_DBLCLK(5000,OnListDoubleClick)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// LdapView construction/destruction

LdapView::LdapView()
{
}

LdapView::~LdapView()
{
}

BOOL LdapView::PreCreateWindow(CREATESTRUCT& cs)
{
	return CView::PreCreateWindow(cs);
}

/////////////////////////////////////////////////////////////////////////////
// LdapView drawing

void LdapView::OnDraw(CDC* pDC)
{
	LdapDoc* pDoc = GetDocument();
	ASSERT_VALID(pDoc);
}

void LdapView::OnInitialUpdate()
{
	CView::OnInitialUpdate();
	// Create a list box the same size as the client area
	CRect rect;
	GetClientRect( &rect );
	m_list.Create( WS_CHILD|WS_VISIBLE|WS_VSCROLL|LBS_NOTIFY, rect, this, 5000 );
}

void LdapView::AddLine( LPCSTR line, const char *dn )
{
	// Add a string to the list box
	int ind = m_list.AddString( line );
	if ( NULL != dn )
		m_list.SetItemDataPtr( ind, (void *)strdup(dn) );
}

void LdapView::ClearLines()
{
	// Remove all lines from the list box
	int nCount = m_list.GetCount();
	while ( nCount > 0 )
	{
		char *str = (char *)m_list.GetItemDataPtr( 0 );
		if ( str )
			free( str );
		nCount = m_list.DeleteString( 0 );
	}
}

/////////////////////////////////////////////////////////////////////////////
// LdapView diagnostics

#ifdef _DEBUG
void LdapView::AssertValid() const
{
	CView::AssertValid();
}

void LdapView::Dump(CDumpContext& dc) const
{
	CView::Dump(dc);
}

LdapDoc* LdapView::GetDocument() // non-debug version is inline
{
	ASSERT(m_pDocument->IsKindOf(RUNTIME_CLASS(LdapDoc)));
	return (LdapDoc*)m_pDocument;
}
#endif //_DEBUG

/////////////////////////////////////////////////////////////////////////////
// LdapView message handlers

void LdapView::OnSize(UINT nType, int cx, int cy) 
{
	// Make sure the list box is resized along with the View
	CView::OnSize(nType, cx, cy);
	if ( ::IsWindow( m_list.m_hWnd ) )
		m_list.SetWindowPos( &wndTop, 0, 0, cx, cy, SWP_NOZORDER );
}

// Fetch all attributes of an entry, and display them in a dialog
void LdapView::showProperties( LDAP *ld, char *dn )
{
	PropDlg dlg;
	if ( ldap_search( ld, dn, LDAP_SCOPE_BASE, "objectclass=*",
				NULL, FALSE ) == -1 )
	{
		AfxMessageBox( "Failed to start asynchronous search" );
		return;
	}

	LDAPMessage *res;
	int rc;
	// Process results as they come in
	while ( (rc = ldap_result( ld, LDAP_RES_ANY, 0, NULL, &res ))
		== LDAP_RES_SEARCH_ENTRY )
	{
		LDAPMessage *e = ldap_first_entry( ld, res );
		BerElement		*ber;
		// Loop over attributes in this entry
		for ( char *a = ldap_first_attribute( ld, e, &ber ); a != NULL;
				a = ldap_next_attribute( ld, e, ber ) )
		{
			struct berval **bvals;
			if ( (bvals = ldap_get_values_len( ld, e, a )) != NULL )
			{
				dlg.AddLine( a );
				// Loop over values for this attribute
				for ( int i = 0; bvals[i] != NULL; i++ )
				{
					CString val;
					val.Format( "    %s", bvals[ i ]->bv_val );
					dlg.AddLine( val );
				}
				ber_bvecfree( bvals );
			}
		}
		if ( ber != NULL )
			ber_free( ber, 0 );
		ldap_msgfree( res );
	}
	if ( rc == -1 )
	{
		AfxMessageBox( "Error on ldap_result" );
		return;
	}
	else if (( rc = ldap_result2error( ld, res, 0 )) != LDAP_SUCCESS )
	{
		char *errString = ldap_err2string( rc );
		AfxMessageBox( errString );
	}
	ldap_msgfree( res );
	// Set the title of the dialog to the distinguished name, and display it
	dlg.SetTitle( dn );
	dlg.DoModal();
}

// Catch double-clicks on the list box, and fetch properties for a dn
void LdapView::OnListDoubleClick()
{
	int ind = m_list.GetCurSel();
	if ( ind >= 0 )
	{
		char *dn = (char *)m_list.GetItemDataPtr( ind );
		if ( NULL != dn )
		{
			LDAP *ld = ((LdapApp *)AfxGetApp())->GetConnection();
			if ( NULL != ld )
				showProperties( ld, dn );
		}
	}
}
