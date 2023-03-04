//  Label StoreMax
//
//  Created by Anthony Gordon.
//  2023, WooSignal Ltd. All rights reserved.
//

//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import 'package:flutter/material.dart';
import 'package:flutter_app/app/models/cart.dart';
import 'package:flutter_app/app/models/cart_line_item.dart';
import 'package:flutter_app/app/models/checkout_session.dart';
import 'package:flutter_app/app/models/customer_address.dart';
import 'package:flutter_app/bootstrap/app_helper.dart';
import 'package:flutter_app/bootstrap/helpers.dart';
import 'package:flutter_app/bootstrap/shared_pref/sp_auth.dart';
import 'package:flutter_app/resources/widgets/app_loader_widget.dart';
import 'package:flutter_app/resources/widgets/buttons.dart';
import 'package:flutter_app/resources/widgets/safearea_widget.dart';
import 'package:flutter_app/resources/widgets/text_row_widget.dart';
import 'package:flutter_app/resources/widgets/woosignal_ui.dart';
import 'package:nylo_framework/nylo_framework.dart';

class CartPage extends StatefulWidget {
  CartPage();

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  _CartPageState();

  bool _isLoading = true, _isCartEmpty = false;
  List<CartLineItem> _cartLines = [];

  @override
  void initState() {
    super.initState();
    _cartCheck();
    CheckoutSession.getInstance.coupon = null;
  }

  _cartCheck() async {
    List<CartLineItem> cart = await Cart.getInstance.getCart();
    if (cart.isEmpty) {
      setState(() {
        _isLoading = false;
        _isCartEmpty = true;
      });
      return;
    }

    List<Map<String, dynamic>> cartJSON = cart.map((c) => c.toJson()).toList();

    List<dynamic> cartRes =
        await (appWooSignal((api) => api.cartCheck(cartJSON)));
    if (cartRes.isEmpty) {
      Cart.getInstance.saveCartToPref(cartLineItems: []);
      setState(() {
        _isCartEmpty = true;
        _isLoading = false;
      });
      return;
    }
    _cartLines = cartRes.map((json) => CartLineItem.fromJson(json)).toList();
    if (_cartLines.isNotEmpty) {
      Cart.getInstance.saveCartToPref(cartLineItems: _cartLines);
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _actionProceedToCheckout() async {
    List<CartLineItem> cartLineItems = await Cart.getInstance.getCart();

    if (_isLoading == true) {
      return;
    }

    if (cartLineItems.isEmpty) {
      showToastNotification(
        context,
        title: trans("Cart"),
        description: trans("You need items in your cart to checkout"),
        style: ToastNotificationStyleType.WARNING,
        icon: Icons.shopping_cart,
      );
      return;
    }

    if (!cartLineItems.every(
        (c) => c.stockStatus == 'instock' || c.stockStatus == 'onbackorder')) {
      showToastNotification(
        context,
        title: trans("Cart"),
        description: trans("There is an item out of stock"),
        style: ToastNotificationStyleType.WARNING,
        icon: Icons.shopping_cart,
      );
      return;
    }

    CheckoutSession.getInstance.initSession();
    CustomerAddress? sfCustomerAddress =
        await CheckoutSession.getInstance.getBillingAddress();

    if (sfCustomerAddress != null) {
      CheckoutSession.getInstance.billingDetails!.billingAddress =
          sfCustomerAddress;
      CheckoutSession.getInstance.billingDetails!.shippingAddress =
          sfCustomerAddress;
    }

    if (AppHelper.instance.appConfig!.wpLoginEnabled == 1 &&
        !(await authCheck())) {
      UserAuth.instance.redirect = "/checkout";
      Navigator.pushNamed(context, "/account-landing");
      return;
    }

    Navigator.pushNamed(context, "/checkout");
  }

  actionIncrementQuantity({required CartLineItem cartLineItem}) {
    if (cartLineItem.isManagedStock! &&
        cartLineItem.quantity + 1 > cartLineItem.stockQuantity!) {
      showToastNotification(
        context,
        title: trans("Cart"),
        description: trans("Maximum stock reached"),
        style: ToastNotificationStyleType.WARNING,
        icon: Icons.shopping_cart,
      );
      return;
    }
    Cart.getInstance
        .updateQuantity(cartLineItem: cartLineItem, incrementQuantity: 1);
    cartLineItem.quantity += 1;
    setState(() {});
  }

  actionDecrementQuantity({required CartLineItem cartLineItem}) {
    if (cartLineItem.quantity - 1 <= 0) {
      return;
    }
    Cart.getInstance
        .updateQuantity(cartLineItem: cartLineItem, incrementQuantity: -1);
    cartLineItem.quantity -= 1;
    setState(() {});
  }

  actionRemoveItem({required int index}) {
    Cart.getInstance.removeCartItemForIndex(index: index);
    _cartLines.removeAt(index);
    showToastNotification(
      context,
      title: trans("Updated"),
      description: trans("Item removed"),
      style: ToastNotificationStyleType.WARNING,
      icon: Icons.remove_shopping_cart,
    );
    if (_cartLines.isEmpty) {
      _isCartEmpty = true;
    }
    setState(() {});
  }

  _clearCart() {
    Cart.getInstance.clear();
    _cartLines = [];
    showToastNotification(context,
        title: trans("Success"),
        description: trans("Cart cleared"),
        style: ToastNotificationStyleType.SUCCESS,
        icon: Icons.delete_outline);
    _isCartEmpty = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          trans("Shopping Cart"),
        ),
        elevation: 1,
        actions: <Widget>[
          InkWell(
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: Align(
              child: Padding(
                child: Text(
                  trans("Clear Cart"),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                padding: EdgeInsets.only(right: 8),
              ),
              alignment: Alignment.centerLeft,
            ),
            onTap: _clearCart,
          )
        ],
        centerTitle: true,
      ),
      body: SafeAreaWidget(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _isCartEmpty
                ? Expanded(
                    child: FractionallySizedBox(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          Icon(
                            Icons.shopping_cart,
                            size: 100,
                            color: Colors.black45,
                          ),
                          Padding(
                            child: Text(
                              trans("Empty Basket"),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            padding: EdgeInsets.only(top: 10),
                          )
                        ],
                      ),
                      heightFactor: 0.5,
                      widthFactor: 1,
                    ),
                  )
                : (_isLoading
                    ? Expanded(
                        child: AppLoaderWidget(),
                      )
                    : Expanded(
                        child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _cartLines.length,
                            itemBuilder: (BuildContext context, int index) {
                              CartLineItem cartLineItem = _cartLines[index];
                              return CartItemContainer(
                                cartLineItem: cartLineItem,
                                actionIncrementQuantity: () =>
                                    actionIncrementQuantity(
                                        cartLineItem: cartLineItem),
                                actionDecrementQuantity: () =>
                                    actionDecrementQuantity(
                                        cartLineItem: cartLineItem),
                                actionRemoveItem: () =>
                                    actionRemoveItem(index: index),
                              );
                            }),
                        flex: 3,
                      )),
            Divider(
              color: Colors.black45,
            ),
            NyFutureBuilder<String>(
              future: Cart.getInstance.getTotal(withFormat: true),
              child: (BuildContext context, data) => Padding(
                child: TextRowWidget(
                  title: trans("Total"),
                  text: (_isLoading ? "" : data),
                ),
                padding: EdgeInsets.only(bottom: 15, top: 15),
              ),
              loading: SizedBox.shrink(),
            ),
            PrimaryButton(
              title: trans("PROCEED TO CHECKOUT"),
              action: _actionProceedToCheckout,
            ),
          ],
        ),
      ),
    );
  }
}
